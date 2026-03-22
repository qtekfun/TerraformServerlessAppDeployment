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
