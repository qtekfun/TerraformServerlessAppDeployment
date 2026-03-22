resource "aws_s3_bucket" "app_serverless_s3_bucket" {
  #checkov:skip=CKV2_AWS_62: S3 event notifications not required; the Lambda writes to this bucket directly and no downstream processing is needed.
  #checkov:skip=CKV_AWS_144: Cross-region replication not required; reports are regenerated on every request so no DR value.
  #checkov:skip=CKV_AWS_18: S3 server-access logging not required; all access is gated via short-lived presigned URLs.
  #checkov:skip=CKV_AWS_21: Versioning not enabled; top.json is deterministically overwritten on every request so versioning adds storage cost without recovery value.
  #checkov:skip=CKV_AWS_145: AES256 SSE is explicitly configured; a KMS CMK is not required for this workload.
  bucket        = "app-serverless-s3-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "s3_access" {
  bucket = aws_s3_bucket.app_serverless_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encryption" {
  bucket = aws_s3_bucket.app_serverless_s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle" {
  bucket = aws_s3_bucket.app_serverless_s3_bucket.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_iam_policy" "s3_policy" {
  name = "s3_policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "s3:ListBucket",
        "Resource" : "arn:aws:s3:::app-serverless-s3-bucket"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        "Resource" : [
          "arn:aws:s3:::app-serverless-s3-bucket/*"
        ]
      }
    ]
  })
}
