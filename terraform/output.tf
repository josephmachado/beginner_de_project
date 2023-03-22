output "aws_region" {
  description = "Region set for AWS"
  value       = var.aws_region
}

output "bucket_name" {
  description = "S3 bucket name."
  value       = aws_s3_bucket.alande-data-lake.id
}

output "redshift_dns_name" {
  description = "Redshift DNS name."
  value       = aws_redshift_cluster.alande_redshift_cluster.dns_name
}

output "redshift_user" {
  description = "Redshift User name."
  value       = "alande_user"
}


output "redshift_password" {
  description = "Redshift password."
  value       = "alandeP0ssword0987"
}

output "ec2_public_dns" {
  description = "EC2 public dns."
  value       = aws_instance.alande_ec2.public_dns
}


output "private_key" {
  description = "EC2 private key."
  value       = tls_private_key.custom_key.private_key_pem
  sensitive   = true
}

output "public_key" {
  description = "EC2 public key."
  value       = tls_private_key.custom_key.public_key_openssh
}

# output "elk_endpoint" {
#   value = aws_elasticsearch_domain.es.endpoint
# }

# output "elk_kibana_endpoint" {
#   value = aws_elasticsearch_domain.es.kibana_endpoint
# }