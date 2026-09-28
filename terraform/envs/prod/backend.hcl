# Where Terraform keeps the state for the prod environment.
# The key (which stack) is added by the Makefile: prod/<stack>.tfstate
#
# Replace 000000000000 with your AWS account ID (the bucket name printed by
# make tf-bootstrap).
bucket       = "uptime-tfstate-000000000000"
region       = "ap-northeast-1"
use_lockfile = true # S3-native locking, no DynamoDB table needed
encrypt      = true
