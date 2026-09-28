# Step 09: Rebuild and replicate

Everything is built, first by hand and then in Terraform, one layer at a time. This last step tests whether the Terraform is really the whole truth:

1. **Replicate:** make a second environment, staging, by changing values only.
2. **Tear down:** delete dev completely, down to the state bucket.
3. **Rebuild:** build dev again from zero, and time it.

If all three work without clicking in the console, the infrastructure is code. If something needs a click, that click is a bug in the code or a gap in the docs.

- **Time:** about 3 hours, most of it waiting for RDS and CloudFront
- **Cost:** a second environment costs as much as dev, about $0.16 an hour. Staging for 3 hours is about $0.50. See [costs.md](../costs.md).
- **You need:** steps 02 to 08 done in dev
- **Branch:** `step-09/rebuild-and-replicate`

## What you will be able to do after this step

- Create a new environment from a folder of values.
- Say exactly what differs between dev, staging and prod, and where that is written.
- Tear an environment down in the right order and prove nothing is left.
- Rebuild an environment from zero and say how long it takes.
- List what Terraform does **not** bring back: data, generated secrets, and the names AWS makes up.

## 1. Words you need

| Word | What it means |
|---|---|
| **Environment** | One full copy of the system: dev, staging or prod. Its own VPC, database, cluster, distribution and state files. |
| **Replica** | An environment made from the same code as another, with different values. |
| **Blast radius** | How much can break when one thing goes wrong. Separate state per stack and per environment keeps it small. |
| **Teardown** | Deleting an environment. Order matters: things that use others go first. |
| **Idempotent** | Running it again changes nothing. `terraform apply` on an up-to-date stack says `No changes`. |

## 2. What differs between environments

Every difference is a value in `terraform/envs/<env>/`. The code in `terraform/stacks` and `terraform/modules` is the same for all of them.

| File | Setting | dev | staging | prod |
|---|---|---|---|---|
| `network.tfvars` | `vpc_cidr` | `10.20.0.0/16` | `10.30.0.0/16` | `10.40.0.0/16` |
| | `nat_gateway_mode` | `single` | `single` | `per_az` |
| `data.tfvars` | `db_instance_class` | `db.t4g.micro` | `db.t4g.micro` | `db.t4g.small` |
| | `db_multi_az` | `false` | `false` | `true` |
| | `db_backup_retention_days` | 1 | 1 | 7 |
| | `db_deletion_protection` | `false` | `false` | `true` |
| | `db_skip_final_snapshot` | `true` | `true` | `false` |
| | `secret_recovery_days` | 0 | 0 | 7 |
| | `reports_force_destroy` | `true` | `true` | `false` |
| `registry.tfvars` | `ecr_force_delete` | `true` | `true` | `false` |
| `compute.tfvars` | API size | 0.25 vCPU, 0.5 GB | 0.25 vCPU, 0.5 GB | 0.5 vCPU, 1 GB |
| | API tasks | 1 | 1 | 2 to 4 |
| | `log_retention_days` | 14 | 14 | 90 |
| | `alb_deletion_protection` | `false` | `false` | `true` |
| `edge.tfvars` | `web_force_destroy` | `true` | `true` | `false` |

Everything that makes prod harder to delete (deletion protection, final snapshots, no force-destroy) is also a value. That is on purpose: in prod, "delete" should need two deliberate steps.

## 3. Replicate: make staging

### 3.1 The values

`terraform/envs/staging/` already exists with the values above. Only the account ID is missing. Replace `000000000000` in `backend.hcl` and `common.tfvars`, as you did for dev in step 02.

Staging can live in the same AWS account as dev (it gets its own VPC and names, `uptime-staging-*`), or in its own account. If it has its own account, run `make tf-bootstrap` there first and use that account's state bucket in `backend.hcl`.

### 3.2 The foundation

```bash
make tf-up env=staging stacks="network security data registry"
```

For each stack this makes a plan, shows it, and asks `Apply staging/network? [y/N]`. Read each plan before you type `y`. You should see the same counts as in dev: 25, 12, 13 and 2 resources. The whole command takes about 15 minutes, mostly RDS.

### 3.3 An image

The new repository `uptime-staging/backend` is empty. Push the same commit dev runs:

```bash
make image-push env=staging
make image-use env=staging tag=<the tag it printed>
```

The first image of a new environment is always pushed by hand: the compute stack cannot even plan until `/uptime-staging/image-tag` exists, and CI's deploy role for staging is only made by the `cicd` stack in 3.4. From then on CI can take over: create the GitHub environment `staging` with its `AWS_DEPLOY_ROLE_ARN`, and set `DEPLOY_STAGING` to `true` (step 08).

### 3.4 The rest

```bash
make tf-up env=staging stacks="compute edge jobs observability cicd"
make web-deploy env=staging
```

You should see 17, 11, 5, 19 (20 with an alert email) and 2 resources, then the web upload. At the end:

```bash
make tf-output env=staging stack=edge name=url; echo
```

prints a new `https://dyyyy.cloudfront.net`. Open it: an empty Uptime. Add the example monitors with a one-off `seed` task (step 04, 8.5, with `uptime-staging` instead of `uptime-dev`). Within two minutes the checks run.

### 3.5 Two environments side by side

```bash
aws ec2 describe-vpcs --filters Name=tag:Project,Values=uptime \
  --query 'Vpcs[].[Tags[?Key==`Environment`]|[0].Value,CidrBlock,VpcId]' --output table
```

You should see two rows: `dev 10.20.0.0/16` and `staging 10.30.0.0/16`. In **Cost Explorer**, group by **Tag: Environment** (tags can take a day to show up there) and you see what each environment costs.

Nothing in dev changed while you did all this. Every stack has its own state file, `staging/<stack>.tfstate`, and its own `.terraform/staging` folder.

## 4. Tear down: delete dev completely

### 4.1 In reverse order

```bash
make tf-down env=dev
```

This runs `tf-destroy` for `cicd`, `observability`, `jobs`, `edge`, `compute`, `registry`, `data`, `security` and `network`, in that order, and Terraform asks `yes` for each. Why reverse? Each stack reads the ones below it. Deleting the network first would fail (the database and the tasks are still in it), and the stacks above would lose the outputs they read.

If a stack was never applied in an environment, leave it out, for example `make tf-down env=dev stacks="jobs edge compute"`.

Expect about 20 to 30 minutes: CloudFront has to disable the distribution before it can delete it, and RDS takes several minutes.

### 4.2 Things Terraform did not make

A few things exist that no stack owns. Check and delete them by hand:

| Thing | Why it exists | What to do |
|---|---|---|
| security group `CloudFront-VPCOrigins-Service-SG` | CloudFront created it for the VPC origin | if the `network` destroy fails with `DependencyViolation`, delete this group, then run it again |
| SSM parameter `/uptime-dev/image-tag` | you (or CI) wrote it with `image-use` | keep it (free), or `aws ssm delete-parameter --name /uptime-dev/image-tag` |
| stopped ECS tasks and inactive task definition revisions | ECS keeps them for a while as history | nothing; they cost nothing |

### 4.3 Prove nothing is left

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Environment,Values=dev \
  --query 'ResourceTagMappingList[].ResourceARN'
aws resourcegroupstaggingapi get-resources --region us-east-1 --tag-filters Key=Environment,Values=dev \
  --query 'ResourceTagMappingList[].ResourceARN'
```

You should see `[]` twice (the second one is for the WAF, which lives in `us-east-1`). Right after a destroy, a few ARNs can still show for a while; the tagging API catches up within about an hour.

Also check the three things that cost the most when forgotten:

```bash
aws ec2 describe-nat-gateways --filter Name=state,Values=available --query 'NatGateways[].NatGatewayId'
aws ec2 describe-addresses --query 'Addresses[].PublicIp'
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'
```

Only staging's should be listed (or nothing, if you already deleted staging).

## 5. Rebuild dev from zero

Now the real test. Time it:

```bash
time make tf-up env=dev stacks="network security data registry"
make image-push env=dev
make image-use env=dev tag=<the tag it printed>
time make tf-up env=dev stacks="compute edge jobs observability cicd"
make web-deploy env=dev
```

The image went away with the registry, so it has to be pushed again before `compute`. Mind the order of `image-push` and `image-use`: `image-use` only writes a tag name into SSM, so run in the wrong order it "works", and then the compute deploy starts tasks that fail with `CannotPullContainerError`, and the circuit breaker rolls back. If you see that, push the image and apply compute again.

Roughly what to expect:

| Stack | Time |
|---|---|
| network | 2 to 3 min (NAT gateway) |
| security | under 1 min |
| data | 6 to 10 min (RDS) |
| registry | seconds |
| image push | 1 to 2 min |
| compute | 3 to 5 min (load balancer, first task) |
| edge | 5 to 15 min (CloudFront, VPC origin) |
| jobs, observability, cicd | under 1 min each |
| **total** | **about 30 to 40 minutes** |

When it is done, open the `url` output. Seed the monitors again. The app works, from nothing, without a single click.

## 6. What Terraform does not bring back

The infrastructure came back. Some things did not, and it matters to know which before you ever need to rebuild prod:

| Thing | After a rebuild | Why | In prod |
|---|---|---|---|
| monitors and check history | **gone** | they were rows in the database, and dev skips the final snapshot | backups for 7 days, a final snapshot on destroy, and deletion protection |
| daily reports | **gone** | the bucket was force-destroyed | `reports_force_destroy = false`: destroy fails while reports exist |
| the admin token | **new value** | it is generated by Terraform | tell whoever uses it; read it from Secrets Manager |
| the database password | new value | generated | nobody needs to know it; ECS reads it |
| CloudFront name `dxxxx.cloudfront.net` | **new name** | AWS makes it up | use a custom domain (step 05, 8.4), so the name users see never changes |
| NAT gateway's public IP | **new IP** | a new Elastic IP | anyone who allowlisted the checker's IP must update it |
| load balancer DNS name | new name | AWS makes it up | nothing to do: CloudFront's VPC origin points at it through Terraform |
| image tags in ECR | gone with the repository | dev force-deletes | `ecr_force_delete = false` in prod |

The lesson: **Terraform rebuilds the house, not the furniture.** Data needs its own plan (backups, snapshots, restore drills), and anything outside the system that depends on a generated name or address needs either a stable name (a domain, an Elastic IP you keep) or a note in the runbook.

## 7. Before the first prod deploy

Prod uses the same code, so most of the work is done. What is left is mostly decisions:

1. **Its own AWS account** is best practice: a mistake in dev cannot reach prod, and the bill is separate. Run `make tf-bootstrap` there, put its account ID and state bucket in `envs/prod`.
2. **A domain** (`edge.tfvars`), so the address users see never changes.
3. **An alert email or chat channel** that someone actually reads (`observability.tfvars`).
4. **The `prod` GitHub environment with required reviewers**, its own `AWS_DEPLOY_ROLE_ARN`, and `DEPLOY_PROD = true` (step 08).
5. **A restore drill.** Restore a point-in-time copy of the prod database to a new instance once, by hand, before you need it. Note how long it takes.

Prod costs about $253 a month (costs.md). Most of the difference from dev is the second NAT gateway, Multi-AZ RDS and two API tasks: the price of surviving a zone failure.

## 8. Check yourself

1. You want a `qa` environment. What do you change in the code?
2. Why must `network` be destroyed last?
3. After a rebuild, a partner says the checks no longer reach their site. What changed?
4. Why does prod have `reports_force_destroy = false` while dev has `true`?
5. The rebuild took 35 minutes. Is that your recovery time if the region were lost? Why or why not?
6. Where is the difference between dev and prod written, and where is it not?

<details>
<summary>Answers</summary>

1. No code: copy `envs/dev` to `envs/qa`, change the values (a new CIDR such as `10.50.0.0/16`, the account ID), and apply the stacks in order. The only rule for the name is that it is short and lowercase.
2. Every other stack puts things inside the VPC (security groups, RDS, tasks, the load balancer, the VPC origin). AWS refuses to delete a VPC that still has anything in it.
3. The NAT gateway's Elastic IP. All checks leave through it, and a rebuild makes a new one. Their allowlist has the old IP.
4. So a destroy cannot silently delete a year of reports. In dev, fast teardown matters more than old CSV files.
5. No. The code rebuilds the infrastructure in about 35 minutes, but the data would have to come from somewhere, and all our backups are in the same region. A real recovery plan needs copies of backups in another region, and a rebuild there, which also needs the region to be a variable (it is: `common.tfvars`).
6. Only in `terraform/envs/<env>/*.tfvars` (and `backend.hcl`). Never in `modules/` or `stacks/`: there is no `if environment == "prod"` anywhere.

</details>

## Clean up everything

When you are done with the whole track:

```bash
make tf-down env=staging
make tf-down env=dev
```

Then check with the commands in 4.3 for both environments.

What remains is the bootstrap: the state bucket (cents a month), the budget (free) and the GitHub OIDC provider (free). You can keep them for next time. To delete them too, the state bucket must be empty (all versions) and its `prevent_destroy` guard removed on purpose:

1. In `terraform/bootstrap/main.tf`, delete the `lifecycle { prevent_destroy = true }` block.
2. Empty the bucket, including old versions, in the S3 console (**Empty**).
3. Destroy it (Terraform asks for `yes`):

   ```bash
   docker run --rm -it --user "$(id -u):$(id -g)" -e HOME=/home/tf -e AWS_PROFILE \
     -v "$PWD":/repo -v ~/.aws:/home/tf/.aws -w /repo/terraform/bootstrap \
     hashicorp/terraform:1.16 destroy -var account_id=ACCOUNT
   ```
4. Put the `lifecycle` block back, so nobody else does this by accident.

## Where to go from here

You have built a small production system the way teams do: layered, in code, in several environments, deployed by a pipeline, watched by alarms. Some directions to go deeper, each worth its own ADR first:

- **Separate AWS accounts** per environment with AWS Organizations, and a shared tools account for ECR.
- **Backups in a second region** (AWS Backup copy rules), and a rebuild in Osaka as a disaster-recovery drill.
- **Versioned database migrations** with expand-and-contract, the moment AutoMigrate is not enough (ADR 0003, ADR 0012).
- **Blue/green deployments** for ECS, with a test listener before switching traffic.
- **Plan on every pull request** for infrastructure changes, with a read-only role.
- **IAM database authentication**, so there is no database password at all (ADR 0009).

The whole architecture in one picture is in the [README](../../README.md#where-we-are-heading). Every decision behind it is in [docs/adr](../adr/README.md).
