# Workbook 05: CloudFront and WAF

Companion to the [step 05 guide](../steps/05-cdn-and-waf.md). Commands marked **(AWS)** talk to your account; you run them.

<p align="center"><img src="../diagrams/step-05-edge.svg" alt="Step 05 edge: CloudFront with WAF, private web bucket through OAC, VPC origin to the internal load balancer" width="100%"></p>

## Before you start

- [ ] Steps 02 to 04 applied in dev; API service running
- [ ] `make web-build` gives `app/web/dist/index.html` and `assets/`
- [ ] Time: about 3 hours (each CloudFront change takes minutes). Cost: WAF about $0.012 an hour; CloudFront inside the free tier.

## Session log

| Date | Start | End | What I did | Left running? (WAF, ALB, RDS, NAT) |
|---|---|---|---|---|
| | | | | |
| | | | | |

## Values I recorded

| What | Where to get it | My value |
|---|---|---|
| app URL | `make tf-output env=dev stack=edge name=url` | |
| distribution ID | `... name=distribution_id` | |
| web bucket | `... name=web_bucket` | |
| custom domain (optional) | `envs/dev/edge.tfvars` | |

## Phase 1. Understand

- [ ] The two behaviors and why `/api/*` is never cached: ______________________
- [ ] What OAC does, and why the bucket is private: ______________________
- [ ] What a VPC origin is, and why the ALB has no public address: ______________________
- [ ] Why a CloudFront Function for deep links, not a custom error response: ______________________
- [ ] Why the WAF lives in `us-east-1`: ______________________
- [ ] Why `PriceClass_200` for users in Japan: ______________________
- [ ] Read [ADR 0013](../adr/0013-cloudfront-vpc-origin-and-waf.md).

## Phase 2. Build by hand (guide section 4)

- [ ] 4.1 Web bucket, build uploaded; direct S3 URL gives `403`
- [ ] 4.2 VPC origin to ALB `uptime-dev` (HTTP 80); `CloudFront-VPCOrigins-Service-SG` appeared; `alb` group allows it on 80
- [ ] 4.3 SPA function published; test `/monitors/1` becomes `/index.html`
- [ ] 4.4 Distribution: S3 origin with OAC, bucket policy pasted; `/api/*` behavior to the VPC origin with `CachingDisabled` + `AllViewerExceptHostHeader`
- [ ] 4.5 Web ACL (Global): IP reputation, core rule set, known bad inputs, rate rule 2000

## Phase 3. Test (guide section 5)

- [ ] App opens at `https://dxxxx.cloudfront.net`; reload on `/monitors/1` works
- [ ] `curl -sI $CF/`: `200`, `strict-transport-security`, `x-cache` Miss then Hit
- [ ] `curl -s $CF/api/health` gives `{"status":"ok"}`, `x-cache` always Miss
- [ ] Adding a monitor through the app works (POST through CloudFront)

## Phase 4. Break it (guide section 6)

| Experiment | Expected | What I saw |
|---|---|---|
| a) remove the VPC origin rule from `alb` | page loads, `/api/health` gives `504` | |
| b) remove the function | `/monitors/1` shows `AccessDenied` XML | |
| c) `?q=<script>alert(1)</script>` | `403` from WAF | |
| d) 3,000 requests, twice | growing number of `403` | |

## Phase 5. Terraform (guide section 8)

Delete the hand-built distribution, VPC origin, web ACL, function, OAC, bucket and the SG rule first (guide section 7), then:

```bash
make tf-plan   env=dev stack=edge     # (AWS) Plan: 11 to add (16 with a domain)
make tf-apply  env=dev stack=edge     # (AWS) 5 to 15 minutes
make web-deploy env=dev               # (AWS) build, upload, invalidate /index.html
make tf-output env=dev stack=edge name=url
```
- [ ] Edge applied (11). If it failed with `no matching EC2 Security Group found`: plan and apply again
- [ ] `web-deploy` printed an invalidation ID; app opens at the `url` output
- [ ] Optional: domain set in `edge.tfvars`, plan `5 to add, 1 to change`, applied, `https://<domain>` works

## Done when

- [ ] I can explain the path of `GET /` and of `GET /api/monitors` from the browser to the origin.
- [ ] I saw the WAF block a request, and know where to find it in the web ACL.
- [ ] I can deploy the web app without users seeing a mix of old and new files, and explain why.
- [ ] I answered the eight "check yourself" questions.

## Clean up

- [ ] Not going on today? **(AWS)** `make tf-destroy env=dev stack=edge` (`11 destroyed`, 5 to 15 minutes)
- [ ] Afterwards: check **EC2, Security groups** for a leftover `CloudFront-VPCOrigins-Service-SG`; delete it once no VPC origin uses the VPC

## If something goes wrong

| What you see | Likely cause | Fix |
|---|---|---|
| `504` on `/api/*` | `alb` group does not allow CloudFront's SG, or no healthy task | security group rule, target group health |
| `403 AccessDenied` XML on `/` | bucket policy missing, or no files uploaded | `make web-deploy`, check the policy's `AWS:SourceArn` |
| `403` on a normal request | a WAF rule matched | web ACL, sampled requests; switch that rule to Count while investigating |
| old page after a deploy | browser or CloudFront kept `index.html` | check it has `Cache-Control: no-cache`; invalidate `/index.html` |
| certificate stuck `Pending validation` | validation record not in the hosted zone | `hosted_zone_id` must be the zone for the domain |

## Notes

