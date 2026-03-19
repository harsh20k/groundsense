# S3 Vectors Bucket for storing embeddings
resource "aws_s3vectors_vector_bucket" "embeddings" {
  vector_bucket_name = "${var.project_name}-${var.environment}-vectors"
  force_destroy      = var.environment == "dev" ? true : false

  tags = {
    Name        = "${var.project_name}-${var.environment}-vectors"
    Project     = var.project_name
    Environment = var.environment
  }
}

# S3 Vector Index for searchable embeddings
resource "aws_s3vectors_index" "documents" {
  vector_bucket_name = aws_s3vectors_vector_bucket.embeddings.vector_bucket_name
  index_name         = "groundsense-docs"
  
  dimension       = 1024  # Amazon Titan Embeddings V2 dimension
  distance_metric = "cosine"
  data_type       = "float32"

  tags = {
    Name        = "groundsense-docs"
    Project     = var.project_name
    Environment = var.environment
  }
}

# IAM Role for Bedrock Knowledge Base
resource "aws_iam_role" "bedrock_kb" {
  name = "${var.project_name}-${var.environment}-bedrock-kb"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-bedrock-kb"
    Project     = var.project_name
    Environment = var.environment
  }
}

# IAM Policy for Bedrock Knowledge Base
resource "aws_iam_role_policy" "bedrock_kb" {
  name = "${var.project_name}-${var.environment}-bedrock-kb-policy"
  role = aws_iam_role.bedrock_kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadDocumentsBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.documents_bucket_arn,
          "${var.documents_bucket_arn}/*"
        ]
      },
      {
        Sid    = "ManageVectorsBucket"
        Effect = "Allow"
        Action = [
          "s3vectors:*"
        ]
        Resource = [
          aws_s3vectors_vector_bucket.embeddings.vector_bucket_arn,
          "${aws_s3vectors_vector_bucket.embeddings.vector_bucket_arn}/*"
        ]
      },
      {
        Sid    = "InvokeEmbeddingModel"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"
      }
    ]
  })
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Bedrock Knowledge Base
resource "aws_bedrockagent_knowledge_base" "main" {
  name     = "${var.project_name}-${var.environment}-kb"
  role_arn = aws_iam_role.bedrock_kb.arn
  description = "Knowledge base for earthquake documents and reports"

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"
    }
  }

  storage_configuration {
    type = "S3_VECTORS"
    s3_vectors_configuration {
      vector_bucket_arn = aws_s3vectors_vector_bucket.embeddings.vector_bucket_arn
      index_name        = aws_s3vectors_index.documents.index_name
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-kb"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Bedrock Data Source (connects to Phase 1 documents bucket)
resource "aws_bedrockagent_data_source" "documents" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.main.id
  name              = "earthquake-documents"
  description       = "Earthquake reports, bulletins, and research documents"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = var.documents_bucket_arn
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 300
        overlap_percentage = 20
      }
    }
  }
}
