output "distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  value = aws_cloudfront_distribution.this.arn
}

output "domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "url" {
  value = "https://${local.use_domain ? var.domain_name : aws_cloudfront_distribution.this.domain_name}"
}

output "vpc_origin_id" {
  value = aws_cloudfront_vpc_origin.alb.id
}
