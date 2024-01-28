resource "aws_s3_bucket" "app-serverless-s3-bucket" {
  bucket = "app-serverless-s3-bucket"
}

data "aws_iam_policy_document" "s3_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListObjects",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = ["arn:aws:s3:::app-serverless-s3-bucket", "arn:aws:s3:::app-serverless-s3-bucket/*"]
  }
}

resource "aws_iam_policy" "s3_policy" {
  name   = "s3_policy"
  policy = data.aws_iam_policy_document.s3_policy_document.json
}
