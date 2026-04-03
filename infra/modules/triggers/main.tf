# SNS topic for earthquake alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-earthquake-alerts"

  tags = {
    Name        = "${var.project_name}-${var.environment}-earthquake-alerts"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Optional email subscription
resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# IAM role for alert Lambda
resource "aws_iam_role" "alert" {
  name = "${var.project_name}-${var.environment}-alert"

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
    Name        = "${var.project_name}-${var.environment}-alert"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "alert" {
  name = "alert-policy"
  role = aws_iam_role.alert.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${var.seismic_archive_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "alert_vpc" {
  role       = aws_iam_role.alert.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Alert Lambda function
data "archive_file" "alert" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/alert"
  output_path = "${path.module}/alert.zip"
}

resource "aws_lambda_function" "alert" {
  filename         = data.archive_file.alert.output_path
  function_name    = "${var.project_name}-${var.environment}-alert"
  role             = aws_iam_role.alert.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.alert.output_base64sha256
  runtime          = "python3.11"
  timeout          = 60

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }

  vpc_config {
    subnet_ids         = [var.private_subnet_id]
    security_group_ids = [var.lambda_security_group_id]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alert"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "alert" {
  name              = "/aws/lambda/${aws_lambda_function.alert.function_name}"
  retention_in_days = 7
}

# S3 permission for alert Lambda
resource "aws_lambda_permission" "alert_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.seismic_archive_bucket_arn
}

# IAM role for KB sync Lambda
resource "aws_iam_role" "kb_sync" {
  name = "${var.project_name}-${var.environment}-kb-sync"

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
    Name        = "${var.project_name}-${var.environment}-kb-sync"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "kb_sync" {
  name = "kb-sync-policy"
  role = aws_iam_role.kb_sync.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${var.documents_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:StartIngestionJob",
          "bedrock:GetIngestionJob",
          "bedrock:ListIngestionJobs"
        ]
        Resource = "arn:aws:bedrock:*:*:knowledge-base/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "kb_sync_vpc" {
  role       = aws_iam_role.kb_sync.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# KB sync Lambda function
data "archive_file" "kb_sync" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/kb_sync"
  output_path = "${path.module}/kb_sync.zip"
}

resource "aws_lambda_function" "kb_sync" {
  filename         = data.archive_file.kb_sync.output_path
  function_name    = "${var.project_name}-${var.environment}-kb-sync"
  role             = aws_iam_role.kb_sync.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.kb_sync.output_base64sha256
  runtime          = "python3.11"
  timeout          = 60

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = var.knowledge_base_id
      DATA_SOURCE_ID    = var.data_source_id
    }
  }

  vpc_config {
    subnet_ids         = [var.private_subnet_id]
    security_group_ids = [var.lambda_security_group_id]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-kb-sync"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "kb_sync" {
  name              = "/aws/lambda/${aws_lambda_function.kb_sync.function_name}"
  retention_in_days = 7
}

# S3 permission for KB sync Lambda
resource "aws_lambda_permission" "kb_sync_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.kb_sync.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.documents_bucket_arn
}
