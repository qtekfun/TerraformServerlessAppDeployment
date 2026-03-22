resource "aws_dynamodb_table" "dynamodb_table" {
  #checkov:skip=CKV_AWS_119: AWS-managed SSE is explicitly enabled. A CMK adds key-management overhead that is not justified for this workload.
  name         = "app-serverless-ddb-table"
  hash_key     = "word"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "word"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }
}

data "aws_iam_policy_document" "access_dynamodb" {
  statement {
    effect = "Allow"
    actions = ["dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:Scan",
    "dynamodb:Query"]
    resources = [aws_dynamodb_table.dynamodb_table.arn]
  }
}

resource "aws_iam_policy" "access_dynamodb_policy" {
  name   = "access_dynamodb_policy"
  policy = data.aws_iam_policy_document.access_dynamodb.json
}
