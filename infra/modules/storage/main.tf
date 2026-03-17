# DynamoDB table for recent earthquake data (30-day TTL)
resource "aws_dynamodb_table" "earthquakes" {
  name           = "${var.project_name}-${var.environment}-earthquakes"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "earthquake_id"

  attribute {
    name = "earthquake_id"
    type = "S"
  }

  ttl {
    enabled        = true
    attribute_name = "expires_at"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-earthquakes"
    Project     = var.project_name
    Environment = var.environment
  }
}

# S3 bucket for seismic event archive
resource "aws_s3_bucket" "seismic_archive" {
  bucket = "${var.project_name}-${var.environment}-seismic-archive"

  tags = {
    Name        = "${var.project_name}-${var.environment}-seismic-archive"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "seismic_archive" {
  bucket = aws_s3_bucket.seismic_archive.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "seismic_archive" {
  bucket = aws_s3_bucket.seismic_archive.id

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# S3 bucket for documents (PDFs, reports)
resource "aws_s3_bucket" "documents" {
  bucket = "${var.project_name}-${var.environment}-documents"

  tags = {
    Name        = "${var.project_name}-${var.environment}-documents"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 event notification for alerts (will be configured after Lambda ARN is available)
resource "aws_s3_bucket_notification" "seismic_archive_alerts" {
  bucket = aws_s3_bucket.seismic_archive.id

  lambda_function {
    lambda_function_arn = var.alert_lambda_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "alerts/"
  }

  depends_on = [var.alert_lambda_permission]
}

# S3 event notification for documents
resource "aws_s3_bucket_notification" "documents_kb_sync" {
  bucket = aws_s3_bucket.documents.id

  lambda_function {
    lambda_function_arn = var.kb_sync_lambda_arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [var.kb_sync_lambda_permission]
}
