output "directory" {
  value       = aws_directory_service_directory.this
  sensitive   = true
  description = "The aws_directory_service resource"
}

output "directory_info" {
  description = "Non-sensitive info from the aws_directory_service_directory resource"
  value = {
    id                = aws_directory_service_directory.this.id
    name              = aws_directory_service_directory.this.name
    access_url        = aws_directory_service_directory.this.access_url
    dns_ip_addresses  = aws_directory_service_directory.this.dns_ip_addresses
    security_group_id = aws_directory_service_directory.this.security_group_id
  }
}

output "file_system" {
  value       = aws_fsx_windows_file_system.this
  description = "The aws_fsx_windows_file_system resource"
}

output "fsx_secret" {
  value       = aws_secretsmanager_secret.fsx
  description = "The aws_secretsmanager_secret resource"
}

output "ad_secret" {
  value       = aws_secretsmanager_secret.ad
  description = "The aws_secretsmanager_secret resource"
}
