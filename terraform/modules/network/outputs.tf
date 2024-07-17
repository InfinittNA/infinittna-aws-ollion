output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "private_subnet_arns" {
  description = "List of ARNs of private subnets"
  value       = module.vpc.private_subnet_arns
}

output "private_subnets_cidr_blocks" {
  description = "List of cidr_blocks of private subnets"
  value       = module.vpc.private_subnets_cidr_blocks
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "public_subnet_arns" {
  description = "List of ARNs of public subnets"
  value       = module.vpc.public_subnet_arns
}

output "public_subnets_cidr_blocks" {
  description = "List of cidr_blocks of public subnets"
  value       = module.vpc.public_subnets_cidr_blocks
}

output "database_subnets" {
  description = "List of IDs of database subnets"
  value       = module.vpc.database_subnets
}

output "database_subnet_arns" {
  description = "List of ARNs of database subnets"
  value       = module.vpc.database_subnet_arns
}

output "database_subnets_cidr_blocks" {
  description = "List of cidr_blocks of database subnets"
  value       = module.vpc.database_subnets_cidr_blocks
}

output "database_subnet_group" {
  description = "ID of database subnet group"
  value       = module.vpc.database_subnet_group
}

output "database_subnet_group_name" {
  description = "Name of database subnet group"
  value       = module.vpc.database_subnet_group_name
}

output "intra_subnets" {
  description = "List of IDs of intra subnets"
  value       = module.vpc.intra_subnets
}

output "intra_subnet_arns" {
  description = "List of ARNs of intra subnets"
  value       = module.vpc.intra_subnet_arns
}


output "nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = module.vpc.nat_public_ips
}

######################################
# VPC flow log
# output "vpc_flow_log_id" {
#   description = "The ID of the Flow Log resource"
#   value       = module.vpc.vpc_flow_log_id
# }

# output "vpc_flow_log_destination_arn" {
#   description = "The ARN of the destination for VPC Flow Logs"
#   value       = module.vpc.vpc_flow_log_destination_arn
# }

# output "vpc_flow_log_destination_type" {
#   description = "The type of the destination for VPC Flow Logs"
#   value       = module.vpc.vpc_flow_log_destination_type
# }

# output "vpc_flow_log_cloudwatch_iam_role_arn" {
#   description = "The ARN of the IAM role used when pushing logs to Cloudwatch log group"
#   value       = module.vpc.vpc_flow_log_cloudwatch_iam_role_arn
# }

#######################################
# VPC endpoints
output "vpc_endpoints" {
  description = "Array containing the full resource object and attributes for all endpoints created"
  value       = module.vpc_endpoints.endpoints
}
