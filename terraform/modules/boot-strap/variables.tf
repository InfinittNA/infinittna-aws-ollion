variable "env" {
  description = "value of the environment"
  type        = string
}

variable "region" {
  description = "The region to deploy the resources"
  type        = string

}

variable "dynamodb_table" {
  description = "The dynamodb table to store the terraform state lock, this prevents concurrent writes to the state file"
  type        = string

}

variable "tags" {
  description = "tags to apply to all resources"
  type        = map(string)
  default = {
    GithubRepo = "ollion-ps-na-tf-infinit-app-poc"
    GithubOrg  = "OllionOrg"
    ManagedBy  = "Terraform"
  }

}

variable "state_bucket_name" {
  description = "The name of the bucket to store the terraform state file"
  type        = string

}

variable "state_bucket_destroy" {
  description = "This bool value will set the bucket to be force destroyed and turn off the lifecycle policy, you will need to apply this change to the bucket to destroy it"
  type        = bool
  default     = false

}
