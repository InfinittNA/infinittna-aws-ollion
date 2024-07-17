# Boot-Strap Module

## Description

This module will deploy the basic resouces for Terraform state management. Please ensure your AWS credentials are set up correctly.

## Usage

1. Create a 'env.tfvars' file in the root of the project with the following content:

```hcl
region = "<region>"
env = "<env>"
dynamodb_table = "<table_name>"
state_bucket = "<bucket_name>"
state_bucket_dest = "<bool_value>
tags = {
    GithubRepo = "ollion-ps-na-tf-infinit-app-poc"
    GithubOrg  = "OllionOrg"
    ManagedBy  = "Terraform"
  }

```

2. Run the following commands locally:

```bash
terraform init
terraform plan -var-file=env.tfvars
terraform apply -var-file=env.tfvars
```

3. Add the following code to the root of your project under the 'terraform' block in the 'config.tf' file:

```hcl
backend "s3" {
region = "<region>"
bucket = "tfstate-dcc"
key = "states/<application_environment>/<app|network>/terraform.tfstate"
dynamodb_table = "<table_name>"
encrypt = "true"
}
```
