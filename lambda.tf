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
  output_path = "lambda_function.zip"
}

data "archive_file" "boto3_layer_zip" {
  type        = "zip"
  source_dir  = "app/boto3_layer"
  output_path = "boto3_layer.zip"
}

resource "aws_lambda_layer_version" "boto3_layer" {
  layer_name          = "boto3_layer"
  filename            = data.archive_file.boto3_layer_zip.output_path
  compatible_runtimes = ["python3.12"]

  source_code_hash = data.archive_file.boto3_layer_zip.output_base64sha256
}

resource "aws_lambda_function" "serverless_app" {
  function_name    = "serverless_app"
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  filename         = "lambda_function.zip"
  role             = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.app_s3_bucketa.bucket
    }
  }

  layers = [
    aws_lambda_layer_version.boto3_layer.arn,
  ]
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name = "/aws/lambda/${aws_lambda_function.serverless_app.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role_policy_attachment" "serverless_app_log_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "s3_write_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.s3_write_attachment_policy.arn
}