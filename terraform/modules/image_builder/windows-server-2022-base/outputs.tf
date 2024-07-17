output "base_windows_server_ami_name" {
  value = aws_imagebuilder_distribution_configuration.windows.tags.Name
}
