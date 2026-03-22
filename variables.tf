variable "aws_region" {
  type        = string
  description = "AWS region for all resources"
  default     = "eu-west-3"
}

variable "presigned_url_expiry" {
  type        = number
  description = "Expiry time in seconds for the S3 presigned URL"
  default     = 600
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log group retention period in days (minimum 365 to satisfy CKV_AWS_338)"
  default     = 365
}

variable "alert_email" {
  type        = string
  description = "Email address for CloudWatch alarm notifications. Leave empty to disable SNS alerts."
  default     = ""
}

variable "monthly_cost_budget_usd" {
  type        = string
  description = "Monthly AWS cost budget in USD. An alert is sent at 80% actual and 100% forecasted."
  default     = "10"
}

variable "enable_s3_versioning" {
  type        = bool
  description = "Enable versioning on the S3 reports bucket. Allows point-in-time recovery of report objects."
  default     = false
}
