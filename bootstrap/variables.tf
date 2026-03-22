variable "aws_region" {
  type        = string
  description = "AWS region for the remote state bucket and lock table"
  default     = "eu-west-3"
}

variable "state_bucket_name" {
  type        = string
  description = "Globally unique name for the S3 bucket that will store Terraform state. Must not already exist."
}

variable "lock_table_name" {
  type        = string
  description = "Name for the DynamoDB table used for state locking"
  default     = "terraform-state-lock"
}
