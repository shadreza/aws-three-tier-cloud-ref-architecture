# 0013. CloudFront in front, S3 for the web app, a VPC origin for the API, WAF on the edge

- Status: Accepted
- Date: 2026-09-29

## Context

Users need one HTTPS address. The browser must only talk to that one origin, because the app has no CORS (step 01): `/` and the pages come from the React build, `/api/*` goes to the Go API. The load balancer is internal (ADR 0005). Most users are in Japan.

## Options

For the web files:

1. **Serve them from the API container.** One less service, but every CSS file hits Fargate, and a deploy of the web app becomes a deploy of the API.
2. **S3 website hosting, public bucket.** Cheap and simple, but the bucket must be public, and S3 website endpoints do not speak HTTPS.
3. **Private S3 bucket behind CloudFront with Origin Access Control (OAC).** The bucket stays private; only our distribution may read it.

For the API:

1. **Internet-facing load balancer, locked to CloudFront** with the CloudFront prefix list and a secret header. Works, but the load balancer is still on the internet, and traffic from CloudFront to it is plain HTTP unless we also buy a domain and a certificate for it.
2. **CloudFront VPC origin to an internal load balancer.** CloudFront reaches the load balancer through network interfaces in our private subnets. No public address, no secret header, no extra cost.

For attacks:

1. **No WAF.** CloudFront already absorbs network floods (AWS Shield Standard, free). Nothing stops application attacks or one client hammering `/api`.
2. **AWS WAF on CloudFront** with AWS-managed rule groups and a rate limit. $5 a month per web ACL, $1 per rule, $0.60 per million requests.
3. **A third-party WAF or CDN.** One more vendor and account.

## Decision

- CloudFront with two origins. Default: the private web bucket through OAC, cached (`Managed-CachingOptimized`). `/api/*`: the internal load balancer through a VPC origin, never cached (`Managed-CachingDisabled`), with every viewer header except `Host` forwarded (so `Authorization` reaches the API).
- A CloudFront Function rewrites paths without a file extension to `/index.html`, so `/monitors/1` loads the React app. It runs only on the web behavior, so an API `404` stays an API `404`. (A "custom error response" that turns every 403/404 into `index.html` would also swallow API errors.)
- `Managed-SecurityHeadersPolicy` adds HSTS and friends on every response.
- Price class `PriceClass_200`: it includes edge locations in Japan. `PriceClass_100` (North America and Europe only) would send Japanese users across the Pacific.
- WAF in `us-east-1` (required for CloudFront) with four rules: a rate limit of 2,000 requests per 5 minutes per IP, the Amazon IP reputation list, the common rule set and the known-bad-inputs rule set. About $9 a month.
- Custom domain optional. Without one, the app is at `https://dxxxx.cloudfront.net` with CloudFront's certificate. With one, Terraform makes an ACM certificate in `us-east-1`, validates it in Route 53 and adds alias records.

## Consequences

- The load balancer, the tasks and the database have no public address. The only way in is CloudFront, and CloudFront passes through the WAF first.
- Traffic from CloudFront to the load balancer is HTTP, but it travels inside AWS's network to our VPC, not over the internet.
- The web app deploys by uploading files and invalidating `index.html`, independent of the API.
- WAF managed rules can block real requests (for example a very large POST body). Blocked requests show up in the WAF metrics and sampled requests (step 07). A rule can be switched to "count" while investigating.
- CloudFront changes take a few minutes to reach every edge location.

## When we would change this

- If the API needs to be called by partners directly, not through CloudFront: add an internet-facing load balancer with its own WAF, in a new ADR.
- If WAF costs matter more than the rules (for example in a throwaway dev), CloudFront's flat-rate plans that bundle WAF, or no WAF in dev, are options worth comparing.
- If users move outside Asia, change the price class.
