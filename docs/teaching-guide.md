# Teaching guide

For someone running this repo as a course or workshop series for a team. It covers how to set up accounts for a group, how to run each session, what people get wrong, and how to check they learned it.

Learners follow the [learning path](learning-path.md), the step guides and the workbooks. This page is the facilitator's side.

## The format that works

Ten sessions of about 2.5 hours, one or two a week. Each session has the same shape:

| Part | Time | What happens |
|---|---|---|
| Recap | 10 min | one learner explains the previous step in two minutes, with its diagram |
| Concept | 20 min | you walk through the step's design section and diagram; learners ask "why not X?" |
| Build by hand | 45 to 60 min | learners click through the console in pairs, one drives, one reads the guide |
| Break it | 20 min | the experiments, as a prediction game (below) |
| Terraform | 30 min | delete the hand-built version, plan, read the plan together, apply |
| Debrief | 15 min | "check yourself" questions out loud, ADR discussion, clean-up check |

Pairs work better than solo: the reader catches skipped steps, and both explain to each other.

## Before the course

### Accounts

Give each learner (or pair) their **own AWS account**. With AWS Organizations, create a `sandbox` organizational unit and one account per learner. Then:

- a **budget** per account (`make tf-bootstrap ... budget_email=` does it, $50 is plenty), with the facilitator's email too
- an IAM Identity Center user per learner, with administrator access to their account only
- a service control policy on the OU that denies all regions except `ap-northeast-1` and `us-east-1` (CloudFront, WAF), so nothing gets built by accident elsewhere

If separate accounts are not possible, learners can share one account with one **environment each**: copy `terraform/envs/dev` to `terraform/envs/<name>` (a short lowercase name) with a unique VPC range (`10.50.0.0/16`, `10.51.0.0/16`...). Resource names include the environment, so they do not collide. One state bucket and one GitHub OIDC provider serve everyone. The hand-built parts need a name prefix per learner (`uptime-<name>-byhand-...`). Separate accounts are still safer: one learner's mistake cannot touch another's work, and the bill is clear per person.

### Cost for the group

Per learner, following the plan with clean-up after each session: about $6 to $8 for the whole course (see the learning path table). Per learner who forgets clean-up for a month: about $120. Check Cost Explorer (grouped by account, or by tag `Environment` in a shared account) the morning after every session for the first two weeks.

### Facilitator preparation

- [ ] Run the whole track yourself once, in a fresh account, recording the times and anything that differed from the guides
- [ ] Prepare the prediction cards for each "break it" experiment (below)
- [ ] Decide GitHub setup for step 08: one fork per learner (each learner owns the repo, environments and variables), or one repo with a `dev` environment per learner
- [ ] Pick two or three ADRs per session for discussion

## Session plans

| # | Step | Goals | Demo by the facilitator | Discussion prompts |
|---|---|---|---|---|
| 1 | 01 | the app, local stack, one check end to end | `make up`, follow a check in the code with the sequence diagram | why one image with many commands? why refuse private addresses? |
| 2 | 02 part 1 | VPC, subnets, routes, NAT by hand | show a route table and say "this line is the only difference" | public tasks and no NAT: when is that a good idea? |
| 3 | 02 part 2 | test machine, experiments, Terraform layout, bootstrap | walk through `terraform/` and one plan | workspaces vs folders per env vs values per env |
| 4 | 03 | RDS, TLS, write-only secrets, S3 | show the state file has `password_wo: null` | Aurora or RDS? rotation now or later? |
| 5 | 04 | ECR, ECS, internal ALB, roles | the bad-image deploy and the rollback, live | execution role vs task role; why migrate as an init container |
| 6 | 05 | CloudFront, OAC, VPC origin, WAF | the XSS request blocked, sampled requests | why not a custom error response for deep links? |
| 7 | 06 | Scheduler, RunTask, PassRole | five runs at once and the lock | a task per run vs a long-running worker; Lambda |
| 8 | 07 | alarms, log metrics, dashboard | pause the jobs and wait for the email | alarm on silence; what should never page someone |
| 9 | 08 | CI, OIDC, deploy role | a merge deploying with no keys | what should CI be allowed to change? |
| 10 | 09 | replicate, tear down, rebuild | time the rebuild on screen | what does Terraform not bring back? what is our recovery plan? |

## Break it: the prediction game

Before each experiment, everyone writes a prediction on a card (or in the workbook): *what will I see, and why?* Then one pair runs it on screen. Score one point for the right symptom, one for the right reason. It turns the experiments from watching into thinking, and the wrong predictions start the best discussions.

Example cards:

- *Step 02: we delete the public route to the internet gateway. What happens to the machine in the **private** subnet?*
- *Step 04: we deploy a tag that does not exist. What do users see?*
- *Step 06: we remove `iam:PassRole` from the scheduler role. Where does the error show up?*
- *Step 07: we pause the schedules. Which alarm fires, and after how long?*

## What people get wrong

| Step | Common mistake | How to catch it |
|---|---|---|
| 02 | thinking a subnet is public because of its name | ask them to show the route table |
| 02 | forgetting to release the Elastic IP after deleting the NAT | `aws ec2 describe-addresses` at the end of the session |
| 03 | trying to connect to RDS from the laptop | ask where the route to the isolated subnet would come from |
| 03 | putting the password in a `.tfvars` file "just for dev" | review diffs before commits |
| 04 | confusing execution role and task role | ask which role reads `DB_PASSWORD` |
| 04 | `image-use` before `image-push` | the plan works, tasks fail to pull; let it happen once |
| 05 | expecting the API to be cached, or the web app not to be | `curl -I` and read `x-cache` together |
| 05 | leaving `CloudFront-VPCOrigins-Service-SG` behind, then the VPC will not delete | teardown checklist |
| 06 | expecting checks exactly on the minute | look at `createdAt` vs `startedAt` together |
| 07 | ignoring the SNS confirmation email | check subscriptions are `Confirmed` |
| 08 | leaving `000000000000` in the env files | first CI run fails at init; point at the workbook |
| 09 | destroying in the wrong order | `make tf-down` does it right; ask why |

## How to check learning

Per step, a learner has done the step when the workbook's **Done when** boxes are ticked and they can answer the "check yourself" questions out loud.

For the whole course, a short practical assessment works better than a quiz. Give each learner a broken environment (their own, broken by you while they are out of the room) and 30 minutes. Examples:

- the private route to the NAT removed: checks stop, `checks-stopped` fires
- the `app` security group rule from `alb` removed: `api-no-healthy-tasks`
- the image tag in SSM set to a tag that does not exist, and compute applied: tasks fail to pull
- the scheduler role's PassRole removed: `scheduler-errors`

| Level | They can |
|---|---|
| 1 | find which alarm fired and read the runbook entry |
| 2 | find the cause with logs, `describe-*` commands and `make tf-plan` (drift) |
| 3 | fix it through Terraform, not the console, and explain why it broke |
| 4 | propose a change (an alarm, a rule, an ADR) so it is caught faster next time |

Finish the course with each learner writing one ADR of their own for a change they would make (from the "where to go from here" list in step 09), and presenting it in five minutes.

## After each session

- [ ] Everyone's session log says what is still running
- [ ] Cost Explorer checked the next morning
- [ ] Anything that differed from the guides written down, and fixed in the repo (a `fix/...` or `docs/...` branch, cherry-picked onto the step's checkpoint)
