# IAM role for seismic poller Lambda
resource "aws_iam_role" "seismic_poller" {
  name = "${var.project_name}-${var.environment}-seismic-poller"

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
    Name        = "${var.project_name}-${var.environment}-seismic-poller"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "seismic_poller" {
  name = "seismic-poller-policy"
  role = aws_iam_role.seismic_poller.id

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
          "dynamodb:PutItem"
        ]
        Resource = var.dynamodb_table_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${var.seismic_archive_bucket_arn}/*"
      }
    ]
  })
}

# Seismic poller Lambda function
data "archive_file" "seismic_poller" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/seismic_poller"
  output_path = "${path.module}/seismic_poller.zip"
}

resource "aws_lambda_function" "seismic_poller" {
  filename         = data.archive_file.seismic_poller.output_path
  function_name    = "${var.project_name}-${var.environment}-seismic-poller"
  role             = aws_iam_role.seismic_poller.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.seismic_poller.output_base64sha256
  runtime          = "python3.11"
  timeout          = 60

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
      S3_BUCKET_NAME      = var.seismic_archive_bucket_name
      TTL_DAYS            = var.dynamodb_ttl_days
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-seismic-poller"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "seismic_poller" {
  name              = "/aws/lambda/${aws_lambda_function.seismic_poller.function_name}"
  retention_in_days = 7
}

# IAM role for document fetcher Lambda
resource "aws_iam_role" "document_fetcher" {
  name = "${var.project_name}-${var.environment}-document-fetcher"

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
    Name        = "${var.project_name}-${var.environment}-document-fetcher"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "document_fetcher" {
  name = "document-fetcher-policy"
  role = aws_iam_role.document_fetcher.id

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
          "s3:PutObject"
        ]
        Resource = "${var.documents_bucket_arn}/*"
      }
    ]
  })
}

# Document fetcher Lambda function
data "archive_file" "document_fetcher" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/document_fetcher"
  output_path = "${path.module}/document_fetcher.zip"
}

resource "aws_lambda_function" "document_fetcher" {
  filename         = data.archive_file.document_fetcher.output_path
  function_name    = "${var.project_name}-${var.environment}-document-fetcher"
  role             = aws_iam_role.document_fetcher.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.document_fetcher.output_base64sha256
  runtime          = "python3.11"
  timeout          = 300

  environment {
    variables = {
      S3_BUCKET_NAME = var.documents_bucket_name
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-document-fetcher"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "document_fetcher" {
  name              = "/aws/lambda/${aws_lambda_function.document_fetcher.function_name}"
  retention_in_days = 7
}

# IAM role for EventBridge Scheduler
resource "aws_iam_role" "scheduler" {
  name = "${var.project_name}-${var.environment}-scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-scheduler"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "scheduler" {
  name = "scheduler-policy"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.seismic_poller.arn,
          aws_lambda_function.document_fetcher.arn
        ]
      }
    ]
  })
}

# EventBridge Scheduler for seismic poller (every 1 minute)
resource "aws_scheduler_schedule" "seismic_poller" {
  name       = "${var.project_name}-${var.environment}-seismic-poller"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(5 minute)"

  target {
    arn      = aws_lambda_function.seismic_poller.arn
    role_arn = aws_iam_role.scheduler.arn
  }
}

# EventBridge Scheduler for document fetcher (daily at 2 AM UTC)
resource "aws_scheduler_schedule" "document_fetcher" {
  name       = "${var.project_name}-${var.environment}-document-fetcher"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(0 2 * * ? *)"

  target {
    arn      = aws_lambda_function.document_fetcher.arn
    role_arn = aws_iam_role.scheduler.arn
  }
}
