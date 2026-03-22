# API key authentication is optional. Set var.api_key to a non-empty value to enable it.
# When disabled (default), the API remains public with no authorizer.
#
# Production note: the API key is passed as a Lambda environment variable here for
# simplicity. For higher security requirements, store the key in AWS Secrets Manager
# and fetch it at runtime instead of via an env var.

locals {
  auth_enabled = var.api_key != ""
}

data "archive_file" "authorizer" {
  count       = local.auth_enabled ? 1 : 0
  type        = "zip"
  source_file = "app/authorizer.py"
  output_path = "authorizer.zip"
}

resource "aws_lambda_function" "authorizer" {
  #checkov:skip=CKV_AWS_117: Authorizer does not access VPC resources; no VPC needed.
  #checkov:skip=CKV_AWS_272: Deployment integrity is enforced via source_code_hash.
  #checkov:skip=CKV_AWS_116: DLQ not applicable; authorizer is invoked synchronously by API Gateway.
  #checkov:skip=CKV_AWS_173: API_KEY should ideally be stored in Secrets Manager for production; env var is acceptable for this workload.
  #checkov:skip=CKV_AWS_115: Reserved concurrency not set; authorizer scales with API traffic.
  count         = local.auth_enabled ? 1 : 0
  function_name = "serverless_app_authorizer"
  runtime       = "python3.12"
  handler       = "authorizer.handler"
  filename      = data.archive_file.authorizer[0].output_path
  role          = aws_iam_role.lambda_execution_role.arn
  timeout       = 5
  publish       = true
  source_code_hash = data.archive_file.authorizer[0].output_base64sha256

  environment {
    variables = {
      API_KEY = var.api_key
    }
  }

  tracing_config {
    mode = "Active"
  }
}

resource "aws_cloudwatch_log_group" "authorizer_log_group" {
  #checkov:skip=CKV_AWS_158: AWS-managed encryption is sufficient for authorizer logs.
  count             = local.auth_enabled ? 1 : 0
  name              = "/aws/lambda/${aws_lambda_function.authorizer[0].function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_permission" "apigateway_invoke_authorizer" {
  count         = local.auth_enabled ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGatewayAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.app_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_authorizer" "api_key_auth" {
  count                             = local.auth_enabled ? 1 : 0
  api_id                            = aws_apigatewayv2_api.app_api.id
  authorizer_type                   = "REQUEST"
  identity_sources                  = ["$request.header.x-api-key"]
  name                              = "api-key-authorizer"
  authorizer_uri                    = aws_lambda_function.authorizer[0].invoke_arn
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
  authorizer_result_ttl_in_seconds  = 300
}
