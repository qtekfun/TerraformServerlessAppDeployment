plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  # Scan all subdirectories (modules)
  call_module_type = "local"
}

rule "aws_lambda_function_invalid_runtime" {
  enabled = true
}

rule "aws_dynamodb_table_invalid_billing_mode" {
  enabled = true
}
