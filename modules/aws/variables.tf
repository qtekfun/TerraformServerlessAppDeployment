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
  description = "CloudWatch log group retention period in days"
  default     = 30
}

variable "alert_email" {
  type        = string
  description = "Email address for CloudWatch alarm notifications. Leave empty to disable SNS alerts."
  default     = ""
}
