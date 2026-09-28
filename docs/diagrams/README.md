# Diagrams

Two kinds of diagrams are used in the docs.

**Architecture pictures** (`*.svg` in this folder) show where things live: the laptop, Docker, the AWS region, the VPC and its subnets. They are hand-placed SVGs that follow one style:

- a colored square with a short code marks what kind of thing a box is:

| Color | Kind | Examples |
|---|---|---|
| orange `#ED7100` | compute | containers, ECS, ECR |
| pink `#E7157B` | jobs and monitoring | scheduler, EventBridge, CloudWatch |
| magenta `#C925D1` | database | MySQL, RDS |
| green `#7AA116` | storage | volumes, S3 |
| purple `#8C4FFF` | networking | load balancer, NAT, Route 53, CloudFront |
| red `#DD344C` | security | WAF, ACM, Secrets Manager |

- a **dashed box** is something that runs and then stops (migrate, check, rollup)
- a **solid arrow** is a request or data, a **dashed arrow** is setup, control or a lookup
- subnet bands use AWS colors: green for public, teal for private, blue for isolated

They switch to dark colors when your system is in dark mode.

To change one, edit `build.py` and run:

```bash
python3 docs/diagrams/build.py
```

**Everything else** (sequences, tables, small flows) is written in [Mermaid](https://mermaid.js.org) right inside the Markdown, so GitHub draws it and anyone can edit it as text. Flowcharts use the same colors as borders through `classDef`.
