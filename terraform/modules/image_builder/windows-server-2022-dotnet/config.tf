terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.46.0"
    }
  }
}

provider "aws" {
  region = "ca-central-1"

}

# Source the VPC module outputs
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    region         = "ca-central-1"
    bucket         = "tfstate-dcc"
    key            = "states/tf-infinitt-app-poc/network/terraform.tfstate"
    dynamodb_table = "tf-infinitt-dcc"
    encrypt        = "true"
  }
}

# Source the base Windows Server 2022 State
data "terraform_remote_state" "base_windows_server_2022" {
  backend = "s3"
  config = {
    region         = "ca-central-1"
    bucket         = "tfstate-dcc"
    key            = "states/tf-infinitt-app-poc/image_builder/base/terraform.tfstate"
    dynamodb_table = "tf-infinitt-dcc"
    encrypt        = "true"
  }

  # backend = "local"
  # config = {
  #   path = "../windows-server-2022-base/terraform.tfstate"
  # }
}

