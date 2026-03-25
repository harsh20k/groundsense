# Dashboard: built-in Lambda metrics for response formatter + Phase 3 tool Lambdas,
# plus custom GroundSense metrics from response_formatter.

locals {
  observability_tool_lambda_names = [
    "${var.project_name}-${var.environment}-get-recent-earthquakes",
    "${var.project_name}-${var.environment}-analyze-patterns",
    "${var.project_name}-${var.environment}-get-hazard",
    "${var.project_name}-${var.environment}-get-location-ctx",
    "${var.project_name}-${var.environment}-fetch-weather",
  ]

  observability_lambda_names = concat(
    [aws_lambda_function.response_formatter.function_name],
    local.observability_tool_lambda_names
  )

  dashboard_duration_metrics_p50 = [
    for name in local.observability_lambda_names : [
      "AWS/Lambda",
      "Duration",
      "FunctionName",
      name,
      { "stat" = "p50" }
    ]
  ]

  dashboard_duration_metrics_p95 = [
    for name in local.observability_lambda_names : [
      "AWS/Lambda",
      "Duration",
      "FunctionName",
      name,
      { "stat" = "p95" }
    ]
  ]

  dashboard_duration_metrics_p99 = [
    for name in local.observability_lambda_names : [
      "AWS/Lambda",
      "Duration",
      "FunctionName",
      name,
      { "stat" = "p99" }
    ]
  ]

  dashboard_errors_metrics = [
    for name in local.observability_lambda_names : [
      "AWS/Lambda",
      "Errors",
      "FunctionName",
      name,
      { "stat" = "Sum" }
    ]
  ]

  dashboard_invocations_metrics = [
    for name in local.observability_lambda_names : [
      "AWS/Lambda",
      "Invocations",
      "FunctionName",
      name,
      { "stat" = "Sum" }
    ]
  ]
}

resource "aws_cloudwatch_dashboard" "agent_observability" {
  dashboard_name = "${var.project_name}-${var.environment}-agent-observability"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        width  = 24
        height = 1
        x      = 0
        y      = 0
        properties = {
          markdown = "## GroundSense — Agent & tool Lambdas (built-in `AWS/Lambda` metrics)\nCustom turn metrics: namespace **${var.metrics_namespace}** (`AgentTurnDurationMs`, `ToolCallsPerTurn`, `AgentTurnSuccess` / `AgentTurnFailure`)."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 24
        height = 6
        properties = {
          metrics = local.dashboard_duration_metrics_p50
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Duration p50 (ms)"
          period  = 300
          stat    = "p50"
          yAxis   = { left = { min = 0 } }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 24
        height = 6
        properties = {
          metrics = local.dashboard_duration_metrics_p95
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Duration p95 (ms)"
          period  = 300
          stat    = "p95"
          yAxis   = { left = { min = 0 } }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 13
        width  = 24
        height = 6
        properties = {
          metrics = local.dashboard_duration_metrics_p99
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Duration p99 (ms)"
          period  = 300
          stat    = "p99"
          yAxis   = { left = { min = 0 } }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 19
        width  = 12
        height = 6
        properties = {
          metrics = local.dashboard_errors_metrics
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Errors (sum)"
          period  = 300
          stat    = "Sum"
          yAxis   = { left = { min = 0 } }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 19
        width  = 12
        height = 6
        properties = {
          metrics = local.dashboard_invocations_metrics
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Invocations (sum)"
          period  = 300
          stat    = "Sum"
          yAxis   = { left = { min = 0 } }
        }
      },
      {
        type   = "text"
        width  = 24
        height = 1
        x      = 0
        y      = 25
        properties = {
          markdown = "## Bedrock agent turn (response_formatter custom metrics)"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 26
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["${var.metrics_namespace}", "AgentTurnDurationMs", "Environment", var.environment, { "stat" = "Average" }],
          ]
          view   = "timeSeries"
          region = var.aws_region
          title  = "Agent turn duration (ms, avg)"
          period = 300
          yAxis  = { left = { min = 0 } }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 26
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["${var.metrics_namespace}", "ToolCallsPerTurn", "Environment", var.environment, { "stat" = "Average" }],
          ]
          view   = "timeSeries"
          region = var.aws_region
          title  = "Tool calls per turn (avg)"
          period = 300
          yAxis  = { left = { min = 0 } }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 32
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["${var.metrics_namespace}", "AgentTurnSuccess", "Environment", var.environment, { "stat" = "Sum" }],
            ["...", "AgentTurnFailure", ".", ".", { "stat" = "Sum" }],
          ]
          view   = "timeSeries"
          region = var.aws_region
          title  = "Agent turn success vs failure (count per period)"
          period = 300
          yAxis  = { left = { min = 0 } }
        }
      },
    ]
  })
}
