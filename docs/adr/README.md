# Architecture Decision Records

An ADR is a short note about one decision: what we chose, what else we looked at, and why. Months later, nobody has to guess why something is the way it is.

## Rules

- One decision per file, numbered: `0004-short-title.md`.
- Write it when the decision is made, not afterwards.
- Never rewrite an old ADR. If we change our mind, write a new one and mark the old one `Superseded by 00XX`.
- Copy [template.md](template.md) to start.

## List

| # | Decision | Status |
|---|---|---|
| [0001](0001-uptime-monitor-as-sample-app.md) | Uptime monitor as the sample app | Accepted |
| [0002](0002-one-backend-image-many-commands.md) | One backend image, many commands | Accepted |
| [0003](0003-gorm-automigrate-for-schema.md) | GORM AutoMigrate for the schema, for now | Accepted |
