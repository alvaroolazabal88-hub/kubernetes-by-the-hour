resource "aws_sns_topic" "alerts" {
  name = "kubernetes-by-the-hour-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "argo_sync_freshness" {
  alarm_name          = "kubernetes-by-the-hour-argo-sync-freshness"
  comparison_operator = "LessThanThreshold"
  evaluation_periods   = 2
  metric_name          = "ArgoSyncCheckCompleted"
  namespace            = "KubernetesByTheHour"
  period               = 900
  statistic            = "Sum"
  threshold            = 1
  treat_missing_data   = "breaching"
  alarm_description    = "No successful Argo CD sync check in the last 30 minutes"
  alarm_actions        = [aws_sns_topic.alerts.arn]
  ok_actions           = [aws_sns_topic.alerts.arn]
}