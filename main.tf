module "aws" {
  source = "./modules/aws"

  aws_region           = var.aws_region
  presigned_url_expiry = var.presigned_url_expiry
  log_retention_days   = var.log_retention_days
  alert_email          = var.alert_email
}