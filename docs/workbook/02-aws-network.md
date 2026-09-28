# Workbook 02: AWS network

Companion to the [step 02 guide](../steps/02-aws-network.md). Commands marked **(AWS)** talk to your account; you run them.

<p align="center"><img src="../diagrams/aws-network.svg" alt="Step 02 network: VPC with public, private and isolated subnets in two zones" width="100%"></p>

## Before you start

- [ ] Step 01 done
- [ ] AWS CLI v2, `jq`, Docker, `make` installed
- [ ] Logged in: `aws sts get-caller-identity` **(AWS)** shows your account
- [ ] `export AWS_PROFILE=... AWS_REGION=ap-northeast-1` in this terminal
- [ ] Time: 3 to 4 hours. Cost: about $0.07 an hour while the NAT gateway exists. **Plan when you will clean up.**

## Session log

| Date | Start | End | What I did | Left running? (NAT, test machines) |
|---|---|---|---|---|
| | | | | |
| | | | | |

## Values I recorded

| What | Where to get it | My value |
|---|---|---|
| AWS account ID | `aws sts get-caller-identity --query Account --output text` | |
| state bucket | output of `make tf-bootstrap` | |
| VPC ID (Terraform) | `make tf-output env=dev stack=network name=vpc_id` | |
| NAT public IP | `make tf-output env=dev stack=network name=nat_public_ips` | |
| private subnet IDs | `... name=private_subnet_ids` | |
| isolated subnet IDs | `... name=isolated_subnet_ids` | |

## Phase 1. Understand

Answer before you build:

- [ ] What makes a subnet public? ______________________
- [ ] Why the NAT gateway sits in a public subnet: ______________________
- [ ] Why the load balancer and the API are in private subnets ([ADR 0005](../adr/0005-three-subnet-tiers-api-in-private.md)): ______________________
- [ ] One NAT versus one per zone: cost of each in Tokyo, and what fails in each ([ADR 0006](../adr/0006-nat-gateways-per-environment.md)): ______________________
- [ ] Why the S3 gateway endpoint saves money: ______________________
- [ ] Read [ADR 0004](../adr/0004-tokyo-region-two-zones.md) and [ADR 0007](../adr/0007-terraform-layout-stacks-and-environments.md).

## Phase 2. Build by hand (guide section 4)

- [ ] Budget alert set (by hand now, or by bootstrap in Phase 5)
- [ ] 4.1 VPC `uptime-dev`, `10.20.0.0/16`, DNS resolution and hostnames on
- [ ] 4.2 Six subnets (public, private, isolated in `1a` and `1c`)
- [ ] 4.3 Internet gateway, attached
- [ ] 4.4 Public route table with `0.0.0.0/0` to the IGW, both public subnets associated
- [ ] 4.5 NAT gateway in `public-1a` with an Elastic IP, **Available** (billing starts)
- [ ] 4.6 Two private route tables, `0.0.0.0/0` to the NAT, one private subnet each
- [ ] 4.7 Isolated route table, no routes, both isolated subnets
- [ ] 4.8 S3 gateway endpoint on both private route tables
- [ ] 4.9 Four security groups (`alb`, `app`, `jobs`, `db`) with the rules from the guide's table
- [ ] 4.10 The three `aws ec2 describe-*` commands **(AWS)** show what the guide says

## Phase 3. Test (guide section 5)

- [ ] Two test security groups (`test-eice`, `test-host`)
- [ ] EC2 Instance Connect Endpoint in `private-1a`
- [ ] `t4g.nano` Amazon Linux 2023 ARM in `private-1a`, no public IP; connected through the endpoint
- [ ] `curl https://example.com` gives `200`
- [ ] `curl https://checkip.amazonaws.com` equals the NAT's Elastic IP
- [ ] The instance has no public IP (`describe-instances` shows `None`)

## Phase 4. Break it (guide section 6)

| Experiment | Expected | What I saw |
|---|---|---|
| a) delete the private `0.0.0.0/0` route | `000`, `exit 28` | |
| b) delete the public `0.0.0.0/0` route | private machine fails too | |
| c) no NAT route, curl S3 | `403` or `405` (S3 answers) | |
| d) machine in an isolated subnet | no internet, no fix possible | |
| e) public subnet, no public IP | no internet | |

- [ ] Every route put back

## Phase 5. Terraform (guide section 8)

Delete the hand-built network first (guide section 7), then:

```bash
# once per account (AWS): state bucket + budget
make tf-bootstrap account_id=ACCOUNT budget_email=you@example.com
```
- [ ] `Plan: 8 to add` (7 on `checkpoint/step-02`; the eighth is the GitHub OIDC provider for step 08), then `state_bucket = "uptime-tfstate-ACCOUNT"`
- [ ] Budget confirmation email received
- [ ] `000000000000` replaced in `terraform/envs/dev/backend.hcl` and `common.tfvars`, both committed

```bash
make tf-plan  env=dev stack=network     # (AWS) Plan: 25 to add
make tf-apply env=dev stack=network     # (AWS) Apply complete! Resources: 25 added
make tf-plan  env=dev stack=security    # (AWS) Plan: 12 to add
make tf-apply env=dev stack=security    # (AWS) Apply complete! Resources: 12 added
make tf-output env=dev stack=network    # (AWS) vpc_id, subnets, nat_public_ips
```
- [ ] Network applied (25)
- [ ] Security applied (12)
- [ ] 4.10 commands show the same shape as the hand-built one, with Terraform names
- [ ] Tags `Project`, `Environment`, `Stack`, `ManagedBy` on the VPC
- [ ] 8.7 drift: deleted a route in the console, `tf-plan` showed `1 to add`, applied to fix
- [ ] 8.8 `per_az` plan shows `2 to add, 1 to change`; **not applied**, set back to `single`

## Done when

- [ ] I can say what makes public, private and isolated different, by pointing at a route table.
- [ ] `make tf-plan env=dev stack=network` says `No changes`.
- [ ] I know what my network costs per hour and per month, and what I delete to stop paying.
- [ ] I answered the seven "check yourself" questions.

## Clean up

Going on to step 03 today? Keep it. Otherwise **(AWS)**:

```bash
make tf-destroy env=dev stack=security   # 12 destroyed
make tf-destroy env=dev stack=network    # 25 destroyed
aws ec2 describe-nat-gateways --filter Name=state,Values=available --query 'NatGateways[].NatGatewayId'
aws ec2 describe-addresses --query 'Addresses[].PublicIp'
```
- [ ] Both lists `[]`. The state bucket stays.

## If something goes wrong

| What you see | Likely cause | Fix |
|---|---|---|
| `Error: AWS account ID not allowed` | terminal logged in to another account | check `AWS_PROFILE`, or the ID in `common.tfvars` |
| `Unable to find remote state` | applying `security` before `network` | apply `network` first |
| `NoSuchBucket` at init | bootstrap not run, or wrong bucket in `backend.hcl` | run `make tf-bootstrap`, fix `backend.hcl` |
| VPC delete fails `DependencyViolation` | something still in it (NAT, instance, endpoint) | delete those first (guide section 7 order) |
| curl from the test machine hangs | missing route or NAT not Available | `describe-route-tables`, NAT state |

## Notes

