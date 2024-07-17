variable "region" {
  description = "The region to deploy the resources"
  type        = string

}

variable "environment" {
  description = "The environment for the resources"
  type        = string

}

variable "state_bucket" {
  description = "The bucket to store the terraform state file"
  type        = string

}

variable "state_bucket_key_path" {
  description = "The path to store the terraform state file state/<env>/<module>/terraform.tfstate"
  type        = string

}

variable "dynamodb_table" {
  description = "The dynamodb table to store the terraform state lock, this prevents concurrent writes to the state file"
  type        = string

}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string

}

variable "vpc_public_subnets" {
  description = "The VPC Public Subnets"
  type        = list(string)

}

variable "vpc_public_subnet_names" {
  description = "The VPC Public Subnet Names"
  type        = list(string)

}

variable "vpc_private_subnets" {
  description = "The VPC Private Subnets"
  type        = list(string)

}

variable "vpc_private_subnet_names" {
  description = "The VPC Private Subnet Names"
  type        = list(string)

}

variable "vpc_database_subnets" {
  description = "The VPC Database Subnets"
  type        = list(string)

}

variable "vpc_database_subnet_names" {
  description = "The VPC Database Subnet Names"
  type        = list(string)

}

variable "create_database_subnet_group" {
  description = "Create a database subnet group"
  type        = bool

}

variable "ad_name" {
  description = "The Active Directory domain name e.g. example.com"
  type        = string

}

variable "ad_log_retention_in_days" {
  description = "The number of days to retain log events"
  type        = number
  default     = 30
}

variable "kms_key_deletion_window_in_days" {
  description = "The number of days to wait before deleting a KMS key"
  type        = number
  default     = 30
}

variable "kms_key_enable_rotation" {
  description = "Enable KMS key rotation"
  type        = bool
  default     = true
}

variable "kms_key_name" {
  description = "The name of the KMS key"
  type        = string

}

variable "fsx_file_system_name" {
  description = "The name of the FSx file system"
  type        = string

}

variable "fsx_deployment_type" {
  description = "The FSx deployment type"
  type        = string
  default     = "SINGLE_AZ_1"

  validation {
    condition     = can(regex("^SINGLE_AZ_1|SINGLE_AZ_2|MULTI_AZ_1$", var.fsx_deployment_type))
    error_message = "Must be one of `SINGLE_AZ_1` or `SINGLE_AZ_2` or `MULTI_AZ_1`."
  }
}

variable "fsx_storage_type" {
  description = "The FSx storage type"
  type        = string
  default     = "HDD"

  validation {
    condition     = can(regex("^SSD|HDD$", var.fsx_storage_type))
    error_message = "Must be one of `SSD` or `HDD`."
  }
}

variable "tags" {
  description = "tags to apply to all resources"
  type        = map(string)

}

variable "ad_manager_instance_type" {
  description = "The instance type for the Active Directory manager"
  type        = string

}

variable "ad_manager_instance_ec2_key_name" {
  description = "The EC2 key pair name for the Active Directory manager"
  type        = string

}
