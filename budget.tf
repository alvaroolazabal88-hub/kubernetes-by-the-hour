resource "aws_budgets_budget" "monthly" {
  name         = "kubernetes-by-the-hour-permanent-budget-alert"
  budget_type  = "COST"
  limit_amount = "70"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 75
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Project$kubernetes-by-the-hour"]
  }
}