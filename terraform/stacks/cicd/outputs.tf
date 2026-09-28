output "deploy_role_arn" {
  description = "Put this in the GitHub environment's variable AWS_DEPLOY_ROLE_ARN."
  value       = aws_iam_role.deploy.arn
}
