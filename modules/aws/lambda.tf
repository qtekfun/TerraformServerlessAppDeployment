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
  #checkov:skip=CKV_AWS_117: Lambda does not access any VPC resources (DynamoDB and S3 are accessed via public AWS endpoints). Adding a VPC would require a NAT Gateway, increasing cost and complexity with no security benefit.
  #checkov:skip=CKV_AWS_272: Code signing is not configured. Deployment integrity is enforced via Terraform's source_code_hash, which rejects any package whose SHA-256 does not match.
  #checkov:skip=CKV_AWS_116: DLQ only applies to asynchronous Lambda invocations. This function is invoked synchronously by API Gateway; errors are returned directly to the caller.
  #checkov:skip=CKV_AWS_173: Environment variables hold only resource identifiers (bucket name, table name, expiry seconds) — no secrets or sensitive data that would benefit from KMS envelope encryption.
  #checkov:skip=CKV_AWS_115: Reserved concurrency is intentionally not set. The function scales freely to absorb variable public API traffic; a fixed limit would throttle legitimate requests.
  function_name    = "serverless_app"
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  filename         = "lambda_function.zip"
  role             = aws_iam_role.lambda_execution_role.arn
  timeout          = 6
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      S3_BUCKET_NAME       = aws_s3_bucket.app_serverless_s3_bucket.bucket
      DYNAMODB_TABLE       = aws_dynamodb_table.dynamodb_table.name
      PRESIGNED_URL_EXPIRY = tostring(var.presigned_url_expiry)
    }
  }

  layers = [
    aws_lambda_layer_version.boto3_layer.arn,
  ]

  tracing_config {
    mode = "Active"
  }
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  #checkov:skip=CKV_AWS_158: AWS-managed encryption is applied to CloudWatch Logs by default. A KMS CMK adds key-management overhead that is not justified for application logs.
  name              = "/aws/lambda/${aws_lambda_function.serverless_app.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role_policy_attachment" "serverless_app_log_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "xray_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy_attachment" "s3_policy_document" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "access_dynamodb" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.access_dynamodb_policy.arn
}
