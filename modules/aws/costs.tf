data "aws_caller_identity" "current" {}

# Monthly cost budget with alerts at 80% actual and 100% forecasted.
# Always created so cost visibility is available even without an alert email.
resource "aws_budgets_budget" "monthly_cost" {
  name         = "serverless-app-monthly-budget"
  account_id   = data.aws_caller_identity.current.account_id
  budget_type  = "COST"
  limit_amount = var.monthly_cost_budget_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = var.alert_email != "" ? [1] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = 80
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.alert_email]
    }
  }

  dynamic "notification" {
    for_each = var.alert_email != "" ? [1] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = 100
      threshold_type             = "PERCENTAGE"
      notification_type          = "FORECASTED"
      subscriber_email_addresses = [var.alert_email]
    }
  }
}

# Cost Anomaly Detection — detects unexpected spending spikes across all AWS services.
# Only provisioned when an alert email is configured.
resource "aws_ce_anomaly_monitor" "service_monitor" {
  count             = var.alert_email != "" ? 1 : 0
  name              = "serverless-app-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "realtime_subscription" {
  count     = var.alert_email != "" ? 1 : 0
  name      = "serverless-app-anomaly-subscription"
  frequency = "IMMEDIATE"

  monitor_arn_list = [aws_ce_anomaly_monitor.service_monitor[0].arn]

  subscriber {
    type    = "EMAIL"
    address = var.alert_email
  }

  # Alert when any single anomaly exceeds $1 in absolute impact.
  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      values        = ["1"]
      match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }
}
