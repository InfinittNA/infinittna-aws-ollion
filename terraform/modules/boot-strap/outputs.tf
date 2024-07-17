output "s3_bucket" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.terraform_state.arn
}

output "s3_bucket_region" {
  value = aws_s3_bucket.terraform_state.region
}

output "dynamic_table" {
  value = aws_dynamodb_table.terraform_state_lock.name
}

output "dynamic_table_arn" {
  value = aws_dynamodb_table.terraform_state_lock.arn
}

output "tags" {
  value = var.tags
}
