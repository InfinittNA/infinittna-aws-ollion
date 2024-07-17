variable "tags" {
  description = "tags to apply to all resources"
  type        = map(string)
  default = {
    ApplicationName = "poc-infinitt-base"
    GithubRepo      = "terraform-aws-vpc"
    GithubOrg       = "terraform-aws-modules"
  }

}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ca-central-1"
}
