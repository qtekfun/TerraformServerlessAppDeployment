module "aws" {
  source = "./modules/aws"

  presigned_url_expiry    = var.presigned_url_expiry
  log_retention_days      = var.log_retention_days
  alert_email             = var.alert_email
  monthly_cost_budget_usd = var.monthly_cost_budget_usd
}