# 0005. Three subnet tiers, API tasks in private subnets

- Status: Accepted
- Date: 2026-09-29

## Context

We need to decide where each piece of the app sits in the network. The pieces are a load balancer, API tasks, scheduled job tasks that call websites on the internet, and a MySQL database.

A subnet is not "public" because of its name. It is public because its route table sends `0.0.0.0/0` (everything outside the VPC) to an **internet gateway**. A **private** subnet sends that traffic to a **NAT gateway** instead, which lets things inside call out but never lets the internet call in. An **isolated** subnet has no route out at all.

## Options

1. **Everything in public subnets, with public IPs on the tasks.** No NAT gateway needed, which saves about $49 a month per NAT. Security groups still block incoming traffic. But one wrong security group rule exposes a task or the database straight to the internet, each task pays $0.005 an hour for its public IPv4 address, and the outgoing address changes with every task, so nobody can allowlist us.
2. **Two tiers: public and private.** Load balancer public, tasks and database private. The database subnets could reach the internet through NAT, which it never needs.
3. **Three tiers: public, private, isolated.** Load balancer and NAT in public, tasks in private, database in isolated subnets with no route out.

## Decision

Three tiers, in two AZs (six subnets):

| Tier | What runs there | Route for `0.0.0.0/0` | CIDR (dev) |
|---|---|---|---|
| public | load balancer, NAT gateway | internet gateway | `10.20.0.0/24`, `10.20.1.0/24` |
| private | ECS tasks: api, check, rollup | NAT gateway | `10.20.10.0/24`, `10.20.11.0/24` |
| isolated | RDS MySQL | none | `10.20.20.0/24`, `10.20.21.0/24` |

The API is in the **private** tier. Only the load balancer can reach it. The check job is also private and reaches websites through the NAT gateway, so every check comes from one fixed IP address (the NAT's Elastic IP).

Each environment gets its own `/16`: dev `10.20.0.0/16`, staging `10.30.0.0/16`, prod `10.40.0.0/16`. They never overlap, so they could be connected later (VPC peering, Transit Gateway) without renumbering.

Security groups point at each other instead of at IP ranges: `alb` to `app` on 8080, `app` and `jobs` to `db` on 3306. The default security group of the VPC has all its rules removed so nothing uses it by accident.

## Consequences

- The database cannot be reached from the internet even if a security group is wrong, because there is no route.
- A person also cannot reach the database from a laptop. To look at it, we run a task or a small instance inside the VPC (step 03 shows how).
- We pay for at least one NAT gateway. [ADR 0006](0006-nat-gateways-per-environment.md) covers how many.
- `/24` subnets have 251 usable addresses (AWS keeps 5). Every Fargate task uses one. That is plenty for this app.

## When we would change this

- If cost matters more than defense in depth for a throwaway environment, a dev VPC with public tasks and no NAT is a valid choice. We would write it down as a new ADR, not just do it.
- If we need IPv6, we would add IPv6 ranges and an egress-only internet gateway (free) for outbound IPv6.
