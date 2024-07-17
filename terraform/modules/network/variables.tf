variable "region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "tags to apply to all resources"
  type        = map(string)

}

variable "environment" {
  description = "The environment for the resources"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}


variable "vpc_public_subnets" {
  description = "The VPC Public Subnets"
  type        = list(string)
  default     = ["10.0.0.0/23", "10.0.2.0/23", "10.0.4.0/23"]
}

variable "vpc_public_subnet_names" {
  description = "The VPC Public Subnet Names"
  type        = list(string)
  default     = ["Public Subnet One", "Public Subnet Two", "Public Subnet Three"]

}

variable "vpc_private_subnets" {
  description = "The VPC Private Subnets"
  type        = list(string)
  default     = ["10.0.32.0/19", "10.0.64.0/19", "10.0.96.0/19", "10.0.128.0/19", "10.0.160.0/19", "10.0.192.0/19"]
}

variable "vpc_private_subnet_names" {
  description = "The VPC Private Subnet Names"
  type        = list(string)
  default     = ["Private Subnet One", "Private Subnet Two", "Private Subnet Three", "Intra Subnet One", "Intra Subnet Two", "Intra Subnet Three"]
}

variable "vpc_database_subnets" {
  description = "The VPC Database Subnets"
  type        = list(string)
  default     = ["10.0.224.0/21", "10.0.232.0/21", "10.0.240.0/21"]
}

variable "vpc_database_subnet_names" {
  description = "The VPC Database Subnet Names"
  type        = list(string)
  default     = ["DB Subnet One", "DB Subnet Two", "DB Subnet Three"]
}

variable "create_database_subnet_group" {
  description = "Create a database subnet group"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames"
  type        = bool
  default     = true

}

variable "enable_dns_support" {
  description = "Enable DNS support"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}

variable "enable_one_nat_gateway_per_az" {
  description = "Enable one NAT Gateway per AZ"
  type        = bool
  default     = true
}

variable "enable_flow_log" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true

}

variable "enable_flow_log_cloudwatch_log_group" {
  description = "Create a Cloudwatch log group for VPC Flow Logs"
  type        = bool
  default     = true
}

variable "create_flow_log_cloudwatch_iam_role" {
  description = "Create an IAM role for VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_log_max_aggregation_interval" {
  description = "The maximum aggregation interval for VPC Flow Logs in seconds"
  type        = number
  default     = 60
}
