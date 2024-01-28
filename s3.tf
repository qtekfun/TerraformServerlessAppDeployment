resource "aws_s3_bucket" "app_s3_bucketa" {
  bucket = "app-s3-bucketa"
}

data "aws_iam_policy_document" "s3_write_attachment" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "s3_write_attachment_policy" {
  name   = "s3_write_attachment_policy"
  policy = data.aws_iam_policy_document.s3_write_attachment.json
}
