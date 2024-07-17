output "windows_server_2022_base_ami_name" {
  value = data.aws_ami.windows.name
}

output "windows_server_2022_base_ami_id" {
  value = data.aws_ami.windows.id
}

output "test" {
  value = "${data.terraform_remote_state.base_windows_server_2022.outputs.base_windows_server_ami_name}-*"
}
