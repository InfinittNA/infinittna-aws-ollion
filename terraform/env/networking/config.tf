terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.46.0"
    }
  }

  # terraform init -backend-config=dev.conf
  backend "s3" {
    key     = "states/tf-infinitt-app-poc/networking/terraform.tfstate"
    encrypt = "true"
  }
}

provider "aws" {
  region = var.region

}
