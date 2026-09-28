# 0010. Daily reports on S3, behind the same interface as the local folder

- Status: Accepted
- Date: 2026-09-29

## Context

The rollup job writes one CSV file per day, and the API lists and serves them. Locally both containers share a Docker volume. On Fargate, every task has its own short-lived disk, so a file written by the rollup task is gone when it stops, and the API tasks never see it.

## Options

1. **EFS**, a shared network file system mounted into every task. The code would not change. But it costs per GB and needs mount targets in each zone and one more security group, for a few KB of CSV a day.
2. **Store the CSV in MySQL** as a text column. No new service, but it mixes files into the database and makes the rows big.
3. **S3**, behind the existing `reports.Store` interface. One bucket per environment, private, encrypted, with a lifecycle rule that deletes old reports.

## Decision

S3. `internal/reports/s3.go` implements `Save`, `List` and `Open` with the AWS SDK. The app uses it when `REPORT_BUCKET` is set, and the local folder otherwise, so local development does not need AWS.

- Bucket: `uptime-<env>-reports-<account>`, prefix `reports/`.
- Reports older than 400 days are deleted by a lifecycle rule.
- Only the ECS task role can read and write it (step 04). The bucket refuses plain HTTP.
- S3 traffic from private subnets goes through the free S3 gateway endpoint (ADR 0006), not the NAT.

## Consequences

- Costs almost nothing: a few KB a day at $0.025 per GB-month.
- The API streams the file from S3. A report the bucket does not have returns `404`; any other S3 error (for example access denied) returns `500` and goes to the logs.
- Local and AWS behavior are the same through one interface, and `s3_test.go` tests the S3 version with a fake client.

## When we would change this

- If users need to download reports directly (large files, many users), the API would hand out short-lived presigned URLs instead of streaming.
