output "api_gateway_uri" {
  value = "${aws_apigatewayv2_api.app_api.api_endpoint}/${aws_apigatewayv2_stage.lambda_stage.name}/"
}