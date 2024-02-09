resource "aws_s3_bucket" "app_serverless_s3_bucket" {
  bucket        = "app-serverless-s3-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "s3_access" {
  bucket = aws_s3_bucket.app_serverless_s3_bucket.id

  block_public_acls   = false
  block_public_policy = false
}

resource "aws_iam_policy" "s3_policy" {
  name = "s3_policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "s3:ListBucket",
        "Resource" : "arn:aws:s3:::app_serverless_s3_bucket"
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
