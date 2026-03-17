# S3 bucket for Athena query results
resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.project_name}-${var.environment}-athena-results"

  tags = {
    Name        = "${var.project_name}-${var.environment}-athena-results"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "expire-old-results"
    status = "Enabled"

    expiration {
      days = 7
    }
  }
}

# Glue database
resource "aws_glue_catalog_database" "seismic_data" {
  name = "${var.project_name}_${var.environment}_seismic_data"

  description = "Seismic event data catalog"
}

# IAM role for Glue Crawler
resource "aws_iam_role" "glue_crawler" {
  name = "${var.project_name}-${var.environment}-glue-crawler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-glue-crawler"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "glue_crawler_service" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_crawler_s3" {
  name = "glue-crawler-s3-policy"
  role = aws_iam_role.glue_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${var.seismic_archive_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = var.seismic_archive_bucket_arn
      }
    ]
  })
}

# Glue Crawler for seismic data
resource "aws_glue_crawler" "seismic_data" {
  name          = "${var.project_name}-${var.environment}-seismic-crawler"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.seismic_data.name

  s3_target {
    path = "s3://${var.seismic_archive_bucket_name}/data/"
  }

  schedule = "cron(0 3 * * ? *)"

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-seismic-crawler"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Athena workgroup
resource "aws_athena_workgroup" "seismic_analysis" {
  name = "${var.project_name}-${var.environment}-seismic-analysis"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-seismic-analysis"
    Project     = var.project_name
    Environment = var.environment
  }
}
