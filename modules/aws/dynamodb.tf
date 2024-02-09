resource "aws_dynamodb_table" "dynamodb_table" {
  name           = "app-serverless-ddb-table"
  hash_key       = "word"
  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "word"
    type = "S"
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
