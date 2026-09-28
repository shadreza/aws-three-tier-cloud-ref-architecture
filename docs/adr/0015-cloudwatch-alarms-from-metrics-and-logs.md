# 0015. CloudWatch only: alarms on AWS metrics and on metrics made from our JSON logs

- Status: Accepted
- Date: 2026-09-29

## Context

After step 06 the app runs by itself. We need to know when it stops working before a user tells us: the API failing or slow, no healthy tasks, the database running out of CPU credits or disk, the scheduler failing to start jobs, or the checks quietly not happening.

The app already writes one JSON log line per event (`log/slog`), and every AWS service we use publishes metrics to CloudWatch for free.

## Options

1. **CloudWatch only.** Alarms on AWS metrics, plus metric filters that turn log lines into metrics. $0.10 per alarm, $0.30 per custom metric, per month. Everything stays in the account.
2. **CloudWatch + Container Insights** for per-task CPU, memory and network. Useful when many services share a cluster; at our size the service-level `CPUUtilization` and `MemoryUtilization` that ECS publishes for free are enough, and Container Insights bills per metric.
3. **An external tool** (Grafana Cloud, Datadog, New Relic...). Better dashboards and tracing, but another account, agent, bill and set of credentials.
4. **Distributed tracing (X-Ray / OpenTelemetry).** Valuable with many services. We have one API and two jobs; a slow request is visible in the request log with `duration_ms`.

## Decision

CloudWatch only, in the `observability` stack:

- One SNS topic per environment (`uptime-<env>-alerts`) with an optional email subscription. Every alarm notifies it on ALARM and on OK.
- Ten alarms: API 5xx, load balancer 5xx, no healthy API tasks, API p95 latency, database CPU, CPU credits, free storage, scheduler target errors, **checks stopped** (no check run finished in 10 minutes), and app errors.
- Three metrics from logs: `CheckRuns` (a heartbeat, one per finished check run), `MonitorsDown` (the value of `down` in `check finished`), and `Errors` (every `level = ERROR` line).
- One dashboard, and three saved Logs Insights queries (slowest requests, errors, check runs per hour).

The "checks stopped" alarm treats missing data as breaching: silence is exactly what it is looking for.

## Consequences

- About $2.40 a month in dev (10 alarms, 3 custom metrics, a little log data). The first three dashboards in an account are free.
- One alarm catches a whole class of failures we did not predict: if anything between the scheduler and the database breaks, `CheckRuns` stops and `checks-stopped` fires.
- Log metric filters depend on the log format. Changing the message `check finished` or the field `down` in the Go code silently breaks two metrics. The names are written down in step 07.
- Email is enough for one person. A team would route the topic to chat or a pager.

## When we would change this

- More services or a team on call: add Container Insights and route alerts to an on-call tool.
- A request that is slow for reasons the logs cannot show: add OpenTelemetry tracing.
- Alerts about the *monitored websites* for users (not for us): that is a product feature, better built in the app than as CloudWatch alarms.
