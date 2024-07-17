output "networking_module" {
  value = module.networking
}

output "fsx_module" {
  value     = module.fsx
  sensitive = true
}
