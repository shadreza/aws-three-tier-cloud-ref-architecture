# 0006. One NAT gateway in dev and staging, one per zone in prod

- Status: Accepted
- Date: 2026-09-29

## Context

Tasks in the private subnets need to go out to the internet. The check job visits websites. Every task pulls its image from ECR, reads secrets and writes logs, and those are AWS APIs on the public internet.

A NAT gateway lives in one Availability Zone. If that zone goes down, private subnets that route through it lose their internet access.

Tokyo prices (check the current ones in [docs/costs.md](../costs.md)):

| | per hour | per month (730 h) |
|---|---|---|
| NAT gateway | $0.062 | $45.26 |
| its Elastic IP (public IPv4) | $0.005 | $3.65 |
| data through it | $0.062 per GB | |

## Options

1. **One NAT gateway for the whole VPC** (`single`). About $49 a month. If its zone fails, tasks in the other zone lose outbound access too. Traffic from the other zone also pays the cross-AZ fee ($0.01 per GB each way).
2. **One NAT gateway per zone** (`per_az`). About $98 a month with two zones. A zone failure only affects that zone, which is already broken.
3. **No NAT gateway, VPC endpoints for every AWS service** (`none`). ECR needs `ecr.api` and `ecr.dkr`, plus `logs`, `secretsmanager`, and more: each interface endpoint costs $0.014 an hour per zone, so five endpoints in two zones is about $102 a month. And the check job still cannot reach websites. Not a fit for this app.
4. **A NAT instance** (a small EC2 instance doing NAT, for example the open-source fck-nat on a `t4g.nano`). About $4 to $5 a month. But we have to patch it, watch it and replace it when it fails. We trade money for work, and that is the wrong trade for a learning repo about managed services.
5. **Public subnets with public IPs on the tasks.** Covered in [ADR 0005](0005-three-subnet-tiers-api-in-private.md). No NAT, but it gives up the private tier.

## Decision

The mode is one variable, `nat_gateway_mode`, set per environment in `terraform/envs/<env>/network.tfvars`:

| Environment | Mode | Why |
|---|---|---|
| dev | `single` | cheapest managed option; an outage here costs nothing |
| staging | `single` | same as dev; staging tests the code, not zone failures |
| prod | `per_az` | a zone failure must not stop the checks in the healthy zone |

We also always add the free **S3 gateway endpoint**. ECR keeps image layers in S3, so every Fargate task start downloads its image through it instead of through the NAT. With a check task every minute that is 43,800 image pulls a month. At about 10 MB each, that would be about 430 GB through the NAT, which is about $27 a month for nothing.

The Terraform module always makes one private route table per zone, even with a single NAT. Moving to `per_az` then only changes where the routes point.

## Consequences

- In dev, if `ap-northeast-1a` fails, checks stop in both zones. We accept that.
- The NAT gateway is the biggest fixed cost of a quiet dev environment. Delete it when you are not using the environment (`nat_gateway_mode = "none"` and apply), and put it back later. The Elastic IP changes when you do this.
- Everything the checker sends comes from the NAT's Elastic IP. Site owners can allowlist it.

## When we would change this

- If outbound traffic grows to many GB a day, interface endpoints for ECR and CloudWatch Logs start paying for themselves and we add them.
- If we need to survive a zone failure in staging (for example to test failover), switch staging to `per_az` for that test.
- If AWS offers a cheaper managed NAT option in Tokyo, we compare it against this table.
