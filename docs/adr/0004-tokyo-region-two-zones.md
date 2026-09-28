# 0004. Tokyo region, two Availability Zones

- Status: Accepted
- Date: 2026-09-29

## Context

The client and most of its users are in Japan. We need to pick one AWS region for everything except the few global services (CloudFront, WAF for CloudFront, ACM for CloudFront).

Inside a region, AWS has several **Availability Zones** (AZs): separate data centers with their own power and network, a few kilometers apart. A load balancer needs subnets in at least two AZs. RDS Multi-AZ needs two.

Tokyo (`ap-northeast-1`) has three AZs that new accounts can use: `ap-northeast-1a`, `ap-northeast-1c` and `ap-northeast-1d`. There is no `ap-northeast-1b` for new accounts.

## Options

1. **Tokyo, `ap-northeast-1`.** Lowest latency for users in Japan (a few milliseconds). Data stays in Japan. Prices are about 20 to 30% higher than `us-east-1`.
2. **Osaka, `ap-northeast-3`.** Also in Japan, but fewer services arrive there first, and it is smaller. A good second region for disaster recovery later.
3. **`us-east-1`.** Cheapest and gets new features first. About 150 ms from Japan, and data leaves the country.

For the number of zones:

1. **Two AZs.** The minimum for a load balancer and Multi-AZ RDS. Two NAT gateways at most.
2. **Three AZs.** Survives losing one zone with more spare capacity, but in a per-AZ design it adds a third NAT gateway (about $49 a month) for little gain at our size.

## Decision

Tokyo, with two AZs: `ap-northeast-1a` and `ap-northeast-1c`. The zone names live in `terraform/envs/<env>/network.tfvars`, not in the code.

## Consequences

- All prices in the docs are Tokyo prices. See [docs/costs.md](../costs.md).
- CloudFront certificates and CloudFront's WAF must still be created in `us-east-1`. Terraform uses a second provider for them (step 05).
- AZ names are mapped differently in each AWS account: your `1a` may be a different building than someone else's `1a`. Only the AZ IDs (like `apne1-az4`) are the same everywhere. For one account this does not matter.

## When we would change this

- Users move mostly outside Japan: pick the region closest to them.
- We need to survive a whole-region outage: add Osaka as a second region.
- We grow to many tasks per zone and one zone going down would overload the rest: use three AZs.
