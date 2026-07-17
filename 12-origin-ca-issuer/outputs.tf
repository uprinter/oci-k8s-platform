output "issuer_name" {
  description = "Name of the ClusterOriginIssuer."
  value       = module.origin-ca-issuer.issuer_name
}

output "certificate_secret_name" {
  description = "Name of the origin certificate Secret consumed by the nginx-gateway listener."
  value       = module.origin-ca-issuer.certificate_secret_name
}
