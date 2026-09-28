# Workbook 01: Understand the application

Companion to the [step 01 guide](../steps/01-understand-the-application.md). No AWS account needed.

<p align="center"><img src="../diagrams/local-architecture.svg" alt="The app on your laptop: browser, web, api, scheduler, mysql and the websites being checked" width="100%"></p>

## Before you start

- [ ] Docker, `make` and `git` installed ([how](../local-development.md#what-you-need))
- [ ] Repo cloned, on `master` or `checkpoint/step-01`
- [ ] About 1 to 2 hours

## Session log

| Date | Start | End | What I did | Left running? |
|---|---|---|---|---|
| | | | | |
| | | | | |

## Phase 1. Understand

Read the README down to **How the pieces fit**, then answer in your own words:

- [ ] The app in one sentence: ____________________________________________
- [ ] The four pieces and what each does:
  - web: ______________________
  - api: ______________________
  - mysql: ____________________
  - scheduler: ________________
- [ ] Why the API and the jobs are one program ([ADR 0002](../adr/0002-one-backend-image-many-commands.md)): ______________________

## Phase 2. Run it

- [ ] `make up`. You should see all containers start, and the hint with `http://localhost:5173`.
- [ ] `make seed`. You should see `example monitors added` with `"count":3`.
- [ ] Open <http://localhost:5173>: one monitor **Up**, one **Down**, "Our own API" **Up** (within a minute).
- [ ] `make ps`. `mysql`, `api`, `scheduler` and `web` are running; `migrate` has exited.

## Phase 3. Follow one check

Open each file and find the name, then tick:

- [ ] `cmd/uptime/main.go`, `runDevScheduler` (the timer)
- [ ] `internal/db/lock.go`, `GET_LOCK` (one run at a time)
- [ ] `internal/checker/checker.go`, `RunOnce` and `checkOne`
- [ ] `internal/netguard/netguard.go`, `DialControl` (private addresses refused)
- [ ] `internal/models/models.go`, `CheckResult`
- [ ] `app/web/src/api.ts`, `listMonitors`
- [ ] `internal/api/monitors.go`, `listMonitors`
- [ ] `make logs s=scheduler` in one terminal, `make check` in another. You should see `check finished`.
- [ ] `make db`, then `SELECT monitor_id, checked_at, is_up FROM check_results ORDER BY id DESC LIMIT 5;` returns rows.

## Phase 4. Break it

- [ ] Stop MySQL (`docker compose stop mysql`): `curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/api/health` still `200`, `/api/ready` gives `503`.
- [ ] Start it again (`docker compose start mysql`): `/api/ready` back to `200` after a few seconds.
- [ ] Try the other experiments in the guide's section 5. What surprised me: ______________________

## Done when

- [ ] I can draw the four pieces and the arrows between them without looking.
- [ ] I can explain `/api/health` versus `/api/ready`, and why the load balancer will use `/api/health`.
- [ ] I can explain why the checker refuses `10.0.0.5` and `169.254.169.254`.
- [ ] I answered the five "check yourself" questions before opening the answers.

## Clean up

- [ ] `make down` (keeps data) or `make reset` (deletes data).

## If something goes wrong

| What you see | Likely cause | Fix |
|---|---|---|
| `port is already allocated` | something else uses 5173, 8080 or 3306 | set another port in `.env` (copy `.env.example`) |
| web page shows `Request failed (502)` | API not started yet, or crashed | `make ps`, then `make logs s=api` |
| `migrate` exited with an error | MySQL not ready, or a bad setting | `make logs s=migrate`, then `make up` again |

## Notes

