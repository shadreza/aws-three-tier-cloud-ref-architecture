# Workbook 07: Observability

Companion to the [step 07 guide](../steps/07-observability.md). Commands marked **(AWS)** talk to your account; you run them.

<p align="center"><img src="../diagrams/step-07-observability.svg" alt="Step 07 observability: metrics and log-based metrics feed alarms, SNS and email" width="100%"></p>

## Before you start

- [ ] Steps 02 to 06 applied in dev; checks running every minute
- [ ] An email address you can read now
- [ ] Time: about 2 hours. Cost: about $2.40 a month.

## Session log

| Date | Start | End | What I did | Left running? |
|---|---|---|---|---|
| | | | | |
| | | | | |

## Values I recorded

| What | Where to get it | My value |
|---|---|---|
| SNS topic ARN | `make tf-output env=dev stack=observability name=alerts_topic_arn` | |
| dashboard URL | `... name=dashboard_url` | |
| time from pausing checks to the ALARM email | your clock | |

## Phase 1. Understand

- [ ] For each failure in the guide's table, the metric that shows it: ______________________
- [ ] Why `checks-stopped` treats missing data as breaching: ______________________
- [ ] Why p95 and not the average for `api-slow`: ______________________
- [ ] Which log messages are now a contract (`check finished`, `down`, `level`): ______________________
- [ ] Read [ADR 0015](../adr/0015-cloudwatch-alarms-from-metrics-and-logs.md).

## Phase 2. Build by hand (guide section 3)

- [ ] SNS topic `uptime-dev-byhand-alerts`, email subscription **confirmed**
- [ ] Metric filter `{ $.msg = "check finished" }` on `/ecs/uptime-dev/jobs`, tested against real lines
- [ ] Alarm `uptime-dev-byhand-checks-stopped`: Sum < 1 in 10 minutes, missing data = breaching, ALARM and OK to the topic

## Phase 3. Test (guide section 4)

- [ ] `aws cloudwatch set-alarm-state --alarm-name uptime-dev-byhand-checks-stopped --state-value ALARM --state-reason test` **(AWS)**: ALARM email, then OK email
- [ ] Paused the jobs: ALARM email within 10 to 20 minutes; resumed: OK email
- [ ] Logs Insights: slowest requests query and check-runs-per-hour query both return rows

## Phase 4. Break it (guide section 5)

| Experiment | Expected | What I saw |
|---|---|---|
| a) API service to 0 tasks | `api-no-healthy-tasks` fires (after section 6); set back to 1 by hand | |
| b) WAF blocks | visible on the dashboard, no alarm | |
| c) DELETE a missing monitor | `404`, no ERROR line, no alarm | |

## Phase 5. Terraform (guide section 6)

Delete the hand-built alarm, filter and topic first, set `alert_email` in `envs/dev/observability.tfvars`, then:

```bash
make tf-plan  env=dev stack=observability   # (AWS) Plan: 20 to add (19 without an email)
make tf-apply env=dev stack=observability   # (AWS)
make tf-output env=dev stack=observability  # (AWS) alarms, dashboard_url
```
- [ ] Observability applied (20); subscription confirmed
- [ ] After 10 minutes `checks-stopped` is `OK`
- [ ] `set-alarm-state` test on `uptime-dev-checks-stopped` delivered both emails
- [ ] Dashboard opened; all nine widgets show data (the WAF one after some traffic)

## Done when

- [ ] I get an email within about 20 minutes when checks stop for any reason.
- [ ] I can find the slowest API request and the latest error from Logs Insights.
- [ ] I know which setting Terraform does not own (`desired_count`) and why.
- [ ] I answered the six "check yourself" questions.

## Clean up

- [ ] Keep it while the environment runs. At teardown, destroy it first **(AWS)**: `make tf-destroy env=dev stack=observability` (`20 destroyed`)

## If something goes wrong

| What you see | Likely cause | Fix |
|---|---|---|
| no email at all | subscription `Pending confirmation` | click the link in the confirmation email |
| an alarm stays `INSUFFICIENT_DATA` | its metric has no data yet (normal at first), or a wrong dimension | wait; compare dimensions in **All metrics** |
| `scheduler-errors` never gets data | AWS/Scheduler dimension name | check the metric in the console; fix `dims` in `observability/main.tf` |
| `checks-stopped` fires but checks run | the log message or filter pattern changed | compare `check finished` in `checker.go` with the filter |

## Notes

