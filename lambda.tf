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
  source_dir  = "app"
  output_path = "lambda_function.zip"
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
      RDS_HOST       = aws_db_instance.my_db_instance.address,
      RDS_USERNAME   = aws_db_instance.my_db_instance.username,
      RDS_PASSWORD   = aws_db_instance.my_db_instance.password,
      RDS_DB_NAME    = aws_db_instance.my_db_instance.db_name,
    }
  }
}