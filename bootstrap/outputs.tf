output "state_bucket_name" {
  description = "Name of the S3 bucket — use this in backend.tf"
  value       = aws_s3_bucket.tfstate.bucket
}

output "lock_table_name" {
  description = "Name of the DynamoDB lock table — use this in backend.tf"
  value       = aws_dynamodb_table.tfstate_lock.name
}
