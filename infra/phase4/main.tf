# =============================================
# Response Formatter Lambda Function
# =============================================

data "aws_caller_identity" "current" {}

# InvokeAgent is evaluated against the agent-alias ARN, not only the agent ARN.
locals {
  agent_alias_arn = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:agent-alias/${var.agent_id}/${var.agent_alias_id}"
}

data "archive_file" "response_formatter" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/response_formatter"
  output_path = "${path.module}/lambda_packages/response_formatter.zip"
}

resource "aws_lambda_function" "response_formatter" {
  filename         = data.archive_file.response_formatter.output_path
  function_name    = "${var.project_name}-${var.environment}-response-formatter"
  role             = aws_iam_role.response_formatter.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.response_formatter.output_base64sha256
  runtime          = "python3.11"
  timeout          = 120
  memory_size      = 512

  environment {
    variables = {
      AGENT_ID          = var.agent_id
      AGENT_ALIAS_ID    = var.agent_alias_id
      METRICS_NAMESPACE = var.metrics_namespace
      ENVIRONMENT       = var.environment
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-response-formatter"
  }
}

# Lambda Function URL (public access for now)
resource "aws_lambda_function_url" "response_formatter" {
  function_name      = aws_lambda_function.response_formatter.function_name
  authorization_type = "NONE"

  # Note: Lambda Function URL CORS rejects "OPTIONS" (each method name must be <= 6 chars).
  # Use "*" to allow POST and browser preflight.
  cors {
    allow_origins = ["*"]
    allow_methods = ["*"]
    allow_headers = ["content-type"]
    max_age       = 86400
  }
}

# =============================================
# IAM Role and Policies
# =============================================

resource "aws_iam_role" "response_formatter" {
  name = "${var.project_name}-${var.environment}-response-formatter-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-response-formatter-role"
  }
}

# CloudWatch Logs permissions
resource "aws_iam_role_policy_attachment" "response_formatter_logs" {
  role       = aws_iam_role.response_formatter.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Bedrock Agent invocation permissions
resource "aws_iam_role_policy" "response_formatter_bedrock" {
  name = "${var.project_name}-${var.environment}-response-formatter-bedrock"
  role = aws_iam_role.response_formatter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeAgent"
        ]
        Resource = [
          var.agent_arn,
          local.agent_alias_arn,
        ]
      }
    ]
  })
}

# Custom metrics (agent turn duration, tool count, success/failure)
resource "aws_iam_role_policy" "response_formatter_cloudwatch_metrics" {
  name = "${var.project_name}-${var.environment}-response-formatter-cw-metrics"
  role = aws_iam_role.response_formatter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = var.metrics_namespace
          }
        }
      }
    ]
  })
}
