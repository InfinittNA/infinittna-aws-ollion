env               = "dev"
region            = "ca-central-1"
dynamodb_table    = "dcc-terraform-state-lock"
state_bucket_name = "dcc-terraform-state-bucket-" # S3 bucket name must be globally unique
tags = {
  Environment = "dev"
  Owner       = "ollion"
}
state_bucket_destroy = false # This sets the bucket as false for force destroy, reapply as true before tearing down environment
