# Bootstrap module — run this ONCE before using S3 remote state.
# It creates the S3 bucket and DynamoDB table that Terraform needs to store
# and lock its state file. The resources here are managed with local state only.
#
# Usage:
#   cd bootstrap
#   terraform init
#   terraform apply -var="state_bucket_name=<globally-unique-bucket-name>"
#
# After apply, copy ../backend.tf.example to ../backend.tf, fill in the bucket
# name from the output, then run:  terraform init   (in the root directory)
# Terraform will offer to migrate the existing local state to S3.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "tfstate" {
  #checkov:skip=CKV2_AWS_62: Event notifications not needed for a state bucket.
  #checkov:skip=CKV_AWS_144: Cross-region replication not required; versioning provides sufficient protection.
  #checkov:skip=CKV_AWS_18: Access logging for the state bucket adds noise without security value.
  #checkov:skip=CKV_AWS_145: AES256 SSE is configured explicitly; a KMS CMK is not required.
  #checkov:skip=CKV2_AWS_61: Lifecycle configuration not needed; versions are retained indefinitely for auditability.
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tfstate_lock" {
  #checkov:skip=CKV_AWS_119: AWS-managed SSE is sufficient for a state lock table.
  #checkov:skip=CKV_AWS_28: PITR not required; the lock table holds no business data.
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }
}
