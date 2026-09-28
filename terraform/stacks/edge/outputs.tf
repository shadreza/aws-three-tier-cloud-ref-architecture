output "url" {
  description = "Open this in your browser."
  value       = module.cdn.url
}

output "distribution_id" {
  value = module.cdn.distribution_id
}

output "distribution_domain_name" {
  value = module.cdn.domain_name
}

output "web_bucket" {
  value = module.web.id
}

output "web_acl_name" {
  value = module.waf.name
}
