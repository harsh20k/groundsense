# Data source for current AWS account
data "aws_caller_identity" "current" {}

# ========================================
# Lambda Function 1: get_recent_earthquakes
# ========================================

# Package Lambda code
data "archive_file" "get_recent_earthquakes" {
  type        = "zip"
  source_dir  = "${path.module}/../../../../lambda/tools/get_recent_earthquakes"
  output_path = "${path.module}/lambda_packages/get_recent_earthquakes.zip"
}

# IAM Role for get_recent_earthquakes Lambda
resource "aws_iam_role" "get_recent_earthquakes" {
  name = "${var.project_name}-${var.environment}-get-recent-earthquakes"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-get-recent-earthquakes"
    Project     = var.project_name
    Environment = var.environment
  }
}

# IAM Policy for get_recent_earthquakes Lambda
resource "aws_iam_role_policy" "get_recent_earthquakes" {
  name = "${var.project_name}-${var.environment}-get-recent-earthquakes-policy"
  role = aws_iam_role.get_recent_earthquakes.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-${var.environment}-get-recent-earthquakes:*"
      },
      {
        Sid    = "DynamoDBQuery"
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "get_recent_earthquakes_vpc" {
  role       = aws_iam_role.get_recent_earthquakes.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Function
resource "aws_lambda_function" "get_recent_earthquakes" {
  filename         = data.archive_file.get_recent_earthquakes.output_path
  function_name    = "${var.project_name}-${var.environment}-get-recent-earthquakes"
  role             = aws_iam_role.get_recent_earthquakes.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.get_recent_earthquakes.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
    }
  }

  vpc_config {
    subnet_ids         = [var.private_subnet_id]
    security_group_ids = [var.lambda_security_group_id]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-get-recent-earthquakes"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ========================================
# Lambda Function 2: analyze_historical_patterns
# ========================================

# Package Lambda code
data "archive_file" "analyze_historical_patterns" {
  type        = "zip"
  source_dir  = "${path.module}/../../../../lambda/tools/analyze_historical_patterns"
  output_path = "${path.module}/lambda_packages/analyze_historical_patterns.zip"
}

# IAM Role for analyze_historical_patterns Lambda
resource "aws_iam_role" "analyze_historical_patterns" {
  name = "${var.project_name}-${var.environment}-analyze-patterns"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-analyze-patterns"
    Project     = var.project_name
    Environment = var.environment
  }
}

# IAM Policy for analyze_historical_patterns Lambda
resource "aws_iam_role_policy" "analyze_historical_patterns" {
  name = "${var.project_name}-${var.environment}-analyze-patterns-policy"
  role = aws_iam_role.analyze_historical_patterns.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-${var.environment}-analyze-patterns:*"
      },
      {
        Sid    = "AthenaQuery"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults"
        ]
        Resource = "arn:aws:athena:${var.aws_region}:${data.aws_caller_identity.current.account_id}:workgroup/${var.athena_workgroup_name}"
      },
      {
        Sid    = "GlueCatalog"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions"
        ]
        Resource = [
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:database/${var.glue_database_name}",
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.glue_database_name}/*"
        ]
      },
      {
        Sid    = "S3AthenaResults"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_athena_output_bucket}",
          "arn:aws:s3:::${var.s3_athena_output_bucket}/*"
        ]
      },
      {
        Sid    = "S3DataLakeRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_seismic_archive_bucket}",
          "arn:aws:s3:::${var.s3_seismic_archive_bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "analyze_historical_patterns_vpc" {
  role       = aws_iam_role.analyze_historical_patterns.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Function
resource "aws_lambda_function" "analyze_historical_patterns" {
  filename         = data.archive_file.analyze_historical_patterns.output_path
  function_name    = "${var.project_name}-${var.environment}-analyze-patterns"
  role             = aws_iam_role.analyze_historical_patterns.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.analyze_historical_patterns.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      ATHENA_WORKGROUP_NAME   = var.athena_workgroup_name
      GLUE_DATABASE_NAME      = var.glue_database_name
      S3_ATHENA_OUTPUT_BUCKET = var.s3_athena_output_bucket
    }
  }

  vpc_config {
    subnet_ids         = [var.private_subnet_id]
    security_group_ids = [var.lambda_security_group_id]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-analyze-patterns"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ========================================
# Lambda Function 3: get_hazard_assessment
# ========================================

# Package Lambda code
data "archive_file" "get_hazard_assessment" {
  type        = "zip"
  source_dir  = "${path.module}/../../../../lambda/tools/get_hazard_assessment"
  output_path = "${path.module}/lambda_packages/get_hazard_assessment.zip"
}

# IAM Role for get_hazard_assessment Lambda
resource "aws_iam_role" "get_hazard_assessment" {
  name = "${var.project_name}-${var.environment}-get-hazard"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-get-hazard"
    Project     = var.project_name
    Environment = var.environment
  }
}

# IAM Policy for get_hazard_assessment Lambda
resource "aws_iam_role_policy" "get_hazard_assessment" {
  name = "${var.project_name}-${var.environment}-get-hazard-policy"
  role = aws_iam_role.get_hazard_assessment.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-${var.environment}-get-hazard:*"
      },
      {
        Sid    = "BedrockKnowledgeBase"
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/${var.knowledge_base_id}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "get_hazard_assessment_vpc" {
  role       = aws_iam_role.get_hazard_assessment.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Function
resource "aws_lambda_function" "get_hazard_assessment" {
  filename         = data.archive_file.get_hazard_assessment.output_path
  function_name    = "${var.project_name}-${var.environment}-get-hazard"
  role             = aws_iam_role.get_hazard_assessment.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.get_hazard_assessment.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = var.knowledge_base_id
    }
  }

  vpc_config {
    subnet_ids         = [var.private_subnet_id]
    security_group_ids = [var.lambda_security_group_id]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-get-hazard"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ========================================
# Lambda Function 4: get_location_context
# ========================================

data "archive_file" "get_location_context" {
  type        = "zip"
  source_dir  = "${path.module}/../../../../lambda/tools/get_location_context"
  output_path = "${path.module}/lambda_packages/get_location_context.zip"
}

resource "aws_iam_role" "get_location_context" {
  name = "${var.project_name}-${var.environment}-get-location-ctx"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-get-location-ctx"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "get_location_context" {
  name = "${var.project_name}-${var.environment}-get-location-ctx-policy"
  role = aws_iam_role.get_location_context.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-${var.environment}-get-location-ctx:*"
      },
      {
        Sid    = "BedrockKnowledgeBase"
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/${var.knowledge_base_id}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "get_location_context_vpc" {
  role       = aws_iam_role.get_location_context.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "get_location_context" {
  filename         = data.archive_file.get_location_context.output_path
  function_name    = "${var.project_name}-${var.environment}-get-location-ctx"
  role             = aws_iam_role.get_location_context.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.get_location_context.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = var.knowledge_base_id
    }
  }

  vpc_config {
    subnet_ids         = [var.private_subnet_id]
    security_group_ids = [var.lambda_security_group_id]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-get-location-ctx"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ========================================
# Lambda Function 5: fetch_weather_at_epicenter
# ========================================

data "archive_file" "fetch_weather_at_epicenter" {
  type        = "zip"
  source_dir  = "${path.module}/../../../../lambda/tools/fetch_weather_at_epicenter"
  output_path = "${path.module}/lambda_packages/fetch_weather_at_epicenter.zip"
}

resource "aws_iam_role" "fetch_weather_at_epicenter" {
  name = "${var.project_name}-${var.environment}-fetch-weather"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-fetch-weather"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "fetch_weather_at_epicenter" {
  name = "${var.project_name}-${var.environment}-fetch-weather-policy"
  role = aws_iam_role.fetch_weather_at_epicenter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-${var.environment}-fetch-weather:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fetch_weather_at_epicenter_vpc" {
  role       = aws_iam_role.fetch_weather_at_epicenter.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "fetch_weather_at_epicenter" {
  filename         = data.archive_file.fetch_weather_at_epicenter.output_path
  function_name    = "${var.project_name}-${var.environment}-fetch-weather"
  role             = aws_iam_role.fetch_weather_at_epicenter.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.fetch_weather_at_epicenter.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256

  vpc_config {
    subnet_ids         = [var.private_subnet_id]
    security_group_ids = [var.lambda_security_group_id]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-fetch-weather"
    Project     = var.project_name
    Environment = var.environment
  }
}
