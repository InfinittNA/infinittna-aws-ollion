variable "region" {
  type        = string
  description = "AWS region"

}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs"
}

variable "ad_name" {
  type        = string
  description = "AD name (FQDN), in the format `example.com`"
}

variable "ad_log_retention_in_days" {
  type        = number
  description = "AD log retention in days"
  default     = 30
}

variable "kms_key_deletion_window_in_days" {
  type        = number
  description = "KMS key deletion window in days"
  default     = 30
}

variable "kms_key_enable_rotation" {
  type        = bool
  description = "Enable KMS key rotation?"
  default     = true
}

variable "kms_key_name" {
  type        = string
  description = "KMS key name, appended to `alias/`"
  default     = "fsx-key"
}

variable "fsx_file_system_name" {
  type        = string
  description = "Name of the FSx Windows file system"
  default     = "infinitt-file-system"
}

variable "fsx_deployment_type" {
  type        = string
  description = "FSx deployment type"
  default     = "SINGLE_AZ_2"
  validation {
    condition     = can(regex("^SINGLE_AZ_1|SINGLE_AZ_2|MULTI_AZ_1$", var.fsx_deployment_type))
    error_message = "Must be one of `SINGLE_AZ_1` or `SINGLE_AZ_2` or `MULTI_AZ_1`."
  }
}

variable "fsx_storage_type" {
  type        = string
  description = "FSx storage type"
  default     = "HDD"
  validation {
    condition     = can(regex("^SSD|HDD$", var.fsx_storage_type))
    error_message = "Must be one of `SSD` or `HDD`."
  }
}

variable "fsx_skip_final_backup" {
  type        = bool
  description = "Skip final FSx backup?"
  default     = true
}

variable "fsx_storage_capacity" {
  type        = number
  description = "FSx Storage capacity"
  default     = 32
}

variable "fsx_throughput_capacity" {
  type        = number
  description = "FSx throughput capacity"
  default     = 8
}

variable "tags" {
  description = "tags to apply to all resources"
  type        = map(string)

}

variable "ad_manager_instance_type" {
  type        = string
  description = "AD manager instance type"
  default     = "t3a.xlarge"

}

variable "ad_manager_instance_ec2_key_name" {
  type        = string
  description = "EC2 key pair name"

}

variable "ad_manager_subnet_id" {
  type        = string
  description = "AD manager subnet ID"

}
