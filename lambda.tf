data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_execution_role" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "app/lambda_function.py"
  output_path = "app/lambda_function.zip"
}

resource "aws_lambda_function" "serverless_app" {
  function_name = "serverless_app"
  runtime       = "python3.12"
  handler       = "lambda_function.lambda_handler"
  filename      = "app/lambda_function.zip"
  role          = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.archive_file.lambda.output_base64sha256
}