locals {
  sns_enabled = var.alert_email != ""
}

resource "aws_sns_topic" "alerts" {
  #checkov:skip=CKV_AWS_26: Using AWS-managed key (alias/aws/sns) is sufficient; a CMK adds operational overhead without meaningful benefit for alarm notifications.
  count             = local.sns_enabled ? 1 : 0
  name              = "serverless-app-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email_alert" {
  count     = local.sns_enabled ? 1 : 0
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "serverless-app-lambda-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Triggers when the Lambda function produces at least one error in a 60-second window"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.serverless_app.function_name
  }

  alarm_actions = local.sns_enabled ? [aws_sns_topic.alerts[0].arn] : []
  ok_actions    = local.sns_enabled ? [aws_sns_topic.alerts[0].arn] : []
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "serverless-app-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  extended_statistic  = "p95"
  threshold           = 5000
  alarm_description   = "Triggers when p95 Lambda duration exceeds 5000 ms (timeout is 6000 ms)"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.serverless_app.function_name
  }

  alarm_actions = local.sns_enabled ? [aws_sns_topic.alerts[0].arn] : []
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  alarm_name          = "serverless-app-dynamodb-throttles"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Triggers when DynamoDB throttles at least one request in a 60-second window"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.dynamodb_table.name
  }

  alarm_actions = local.sns_enabled ? [aws_sns_topic.alerts[0].arn] : []
}
