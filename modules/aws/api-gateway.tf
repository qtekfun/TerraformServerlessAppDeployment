resource "aws_apigatewayv2_api" "app_api" {
  name          = "app-http-api"
  protocol_type = "HTTP"
}

resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  #checkov:skip=CKV_AWS_158: AWS-managed encryption is applied to CloudWatch Logs by default. A KMS CMK adds key-management overhead that is not justified for access logs.
  name              = "/aws/apigateway/${aws_apigatewayv2_api.app_api.id}"
  retention_in_days = var.log_retention_days
}

resource "aws_apigatewayv2_stage" "lambda_stage" {
  api_id      = aws_apigatewayv2_api.app_api.id
  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_log_group.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      sourceIp       = "$context.identity.sourceIp"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      durationMs     = "$context.responseLatency"
      errorMessage   = "$context.error.message"
    })
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.app_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.serverless_app.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "lambda_route" {
  #checkov:skip=CKV_AWS_309: This is a public API by design. Authentication (API key or JWT authorizer) is listed as a future roadmap item in the README.
  api_id    = aws_apigatewayv2_api.app_api.id
  route_key = "POST /"

  target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "apigateway_invoke_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.serverless_app.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.app_api.execution_arn}/*/*"
}
