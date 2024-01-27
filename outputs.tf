
output "api_gateway_uri" {
  value = "${aws_apigatewayv2_api.app_api.api_endpoint}/${aws_apigatewayv2_stage.lambda_stage.name}/"
}

output "rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.my_db_instance.address
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.my_db_instance.port
  sensitive   = true
}

output "rds_username" {
  description = "RDS instance root username"
  value       = aws_db_instance.my_db_instance.username
  sensitive   = true
}