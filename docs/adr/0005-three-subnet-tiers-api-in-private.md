# 0005. Three subnet tiers, API and load balancer in private subnets

- Status: Accepted
- Date: 2026-09-29

## Context

We need to decide where each piece of the app sits in the network. The pieces are a load balancer, API tasks, scheduled job tasks that call websites on the internet, and a MySQL database. CloudFront (step 05) is the only way users reach the app.

A subnet is not "public" because of its name. It is public because its route table sends `0.0.0.0/0` (everything outside the VPC) to an **internet gateway**. A **private** subnet sends that traffic to a **NAT gateway** instead, which lets things inside call out but never lets the internet call in. An **isolated** subnet has no route out at all.

## Options

1. **Everything in public subnets, with public IPs on the tasks.** No NAT gateway needed, which saves about $49 a month per NAT. Security groups still block incoming traffic. But one wrong security group rule exposes a task or the database straight to the internet, each task pays $0.005 an hour for its public IPv4 address, and the outgoing address changes with every task, so nobody can allowlist us.
2. **Two tiers: public and private.** Tasks and database private. The database subnets could reach the internet through NAT, which it never needs.
3. **Three tiers: public, private, isolated.** NAT in public, tasks in private, database in isolated subnets with no route out.

And for the load balancer:

1. **Internet-facing load balancer in the public subnets.** The classic layout. Anyone can reach it, so it has to be locked down to CloudFront with the CloudFront IP prefix list (which uses about 55 of the 60 rules a security group may have) plus a secret header that CloudFront adds and the load balancer checks. It also pays for one public IPv4 address per zone ($7.30 a month), and traffic between CloudFront and the load balancer crosses the internet, in plain HTTP unless we also buy a domain and a certificate for it.
2. **Internal load balancer in the private subnets, reached through a CloudFront VPC origin.** CloudFront puts its own network interfaces into our private subnets and talks to the load balancer over AWS's private network. The load balancer has no public address at all. VPC origins cost nothing extra.

## Decision

Three tiers, in two AZs (six subnets):

| Tier | What runs there | Route for `0.0.0.0/0` | CIDR (dev) |
|---|---|---|---|
| public | NAT gateway | internet gateway | `10.20.0.0/24`, `10.20.1.0/24` |
| private | internal load balancer, ECS tasks (api, check, rollup), CloudFront VPC origin interfaces | NAT gateway | `10.20.10.0/24`, `10.20.11.0/24` |
| isolated | RDS MySQL | none | `10.20.20.0/24`, `10.20.21.0/24` |

The load balancer is **internal** and sits in the private tier with the API. CloudFront reaches it through a VPC origin (step 05); nothing on the internet can. The API tasks only accept traffic from the load balancer. The check job is also private and reaches websites through the NAT gateway, so every check comes from one fixed IP address (the NAT's Elastic IP).

Each environment gets its own `/16`: dev `10.20.0.0/16`, staging `10.30.0.0/16`, prod `10.40.0.0/16`. They never overlap, so they could be connected later (VPC peering, Transit Gateway) without renumbering.

Security groups point at each other instead of at IP ranges: `alb` to `app` on 8080, `app` and `jobs` to `db` on 3306. The default security group of the VPC has all its rules removed so nothing uses it by accident.

## Consequences

- The database cannot be reached from the internet even if a security group is wrong, because there is no route.
- A person also cannot reach the database from a laptop. To look at it, we run a task or a small instance inside the VPC (step 03 shows how).
- The public subnets hold only the NAT gateway. They still matter: the NAT gateway and the VPC origin both need the internet gateway.
- Before CloudFront exists (step 04), you test the load balancer from inside the VPC, with the debug host.
- We pay for at least one NAT gateway. [ADR 0006](0006-nat-gateways-per-environment.md) covers how many.
- `/24` subnets have 251 usable addresses (AWS keeps 5). Every Fargate task uses one. That is plenty for this app.

## When we would change this

- If something other than CloudFront must reach the load balancer directly (a partner calling the API, for example), we would add an internet-facing load balancer for that, with its own ADR.

- If cost matters more than defense in depth for a throwaway environment, a dev VPC with public tasks and no NAT is a valid choice. We would write it down as a new ADR, not just do it.
- If we need IPv6, we would add IPv6 ranges and an egress-only internet gateway (free) for outbound IPv6.
