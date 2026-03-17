data "aws_caller_identity" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  name_prefix  = "${var.project_name}-${var.environment}"
}

data "aws_iam_policy_document" "project_owner" {
  # Lambda
  statement {
    sid    = "LambdaManage"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:DeleteFunction",
      "lambda:GetFunction",
      "lambda:ListFunctions",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:GetPolicy",
      "lambda:InvokeFunction",
      "lambda:TagResource",
      "lambda:ListTags",
    ]
    resources = [
      "arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${local.name_prefix}-*",
    ]
  }

  # DynamoDB
  statement {
    sid    = "DynamoDBManage"
    effect = "Allow"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DeleteTable",
      "dynamodb:DescribeTable",
      "dynamodb:UpdateTable",
      "dynamodb:ListTables",
      "dynamodb:TagResource",
      "dynamodb:ListTagsOfResource",
      "dynamodb:UpdateTimeToLive",
      "dynamodb:DescribeTimeToLive",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${local.name_prefix}-*",
    ]
  }

  # S3 – bucket-level
  statement {
    sid    = "S3BucketManage"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:GetBucketNotification",
      "s3:PutBucketNotification",
      "s3:PutBucketVersioning",
      "s3:GetBucketVersioning",
      "s3:PutBucketTagging",
      "s3:GetBucketTagging",
      "s3:PutLifecycleConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:PutBucketPublicAccessBlock",
      "s3:GetBucketPublicAccessBlock",
    ]
    resources = [
      "arn:aws:s3:::${local.name_prefix}-*",
    ]
  }

  # S3 – object-level
  statement {
    sid    = "S3ObjectManage"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucketMultipartUploads",
    ]
    resources = [
      "arn:aws:s3:::${local.name_prefix}-*/*",
    ]
  }

  # EventBridge Scheduler
  statement {
    sid    = "SchedulerManage"
    effect = "Allow"
    actions = [
      "scheduler:CreateSchedule",
      "scheduler:UpdateSchedule",
      "scheduler:DeleteSchedule",
      "scheduler:GetSchedule",
      "scheduler:ListSchedules",
      "scheduler:TagResource",
      "scheduler:ListTagsForResource",
    ]
    resources = [
      "arn:aws:scheduler:${var.aws_region}:${local.account_id}:schedule/default/${local.name_prefix}-*",
    ]
  }

  # SNS
  statement {
    sid    = "SNSManage"
    effect = "Allow"
    actions = [
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:GetTopicAttributes",
      "sns:SetTopicAttributes",
      "sns:Subscribe",
      "sns:Unsubscribe",
      "sns:ListSubscriptionsByTopic",
      "sns:TagResource",
      "sns:ListTagsForResource",
    ]
    resources = [
      "arn:aws:sns:${var.aws_region}:${local.account_id}:${local.name_prefix}-*",
    ]
  }

  # Glue
  statement {
    sid    = "GlueManage"
    effect = "Allow"
    actions = [
      "glue:CreateDatabase",
      "glue:DeleteDatabase",
      "glue:GetDatabase",
      "glue:UpdateDatabase",
      "glue:CreateCrawler",
      "glue:DeleteCrawler",
      "glue:GetCrawler",
      "glue:UpdateCrawler",
      "glue:StartCrawler",
      "glue:StopCrawler",
      "glue:TagResource",
      "glue:ListCrawlers",
    ]
    resources = [
      "arn:aws:glue:${var.aws_region}:${local.account_id}:catalog",
      "arn:aws:glue:${var.aws_region}:${local.account_id}:database/${local.name_prefix}-*",
      "arn:aws:glue:${var.aws_region}:${local.account_id}:crawler/${local.name_prefix}-*",
    ]
  }

  # Athena
  statement {
    sid    = "AthenaManage"
    effect = "Allow"
    actions = [
      "athena:CreateWorkGroup",
      "athena:DeleteWorkGroup",
      "athena:GetWorkGroup",
      "athena:UpdateWorkGroup",
      "athena:ListWorkGroups",
      "athena:TagResource",
      "athena:ListTagsForResource",
    ]
    resources = [
      "arn:aws:athena:${var.aws_region}:${local.account_id}:workgroup/${local.name_prefix}-*",
    ]
  }

  # IAM – scoped to project roles/policies
  statement {
    sid    = "IAMManage"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:TagRole",
      "iam:TagPolicy",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${local.name_prefix}-*",
      "arn:aws:iam::${local.account_id}:policy/${local.name_prefix}-*",
    ]
  }

  # CloudWatch Logs
  statement {
    sid    = "CloudWatchLogsManage"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:TagLogGroup",
      "logs:ListTagsLogGroup",
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/lambda/${local.name_prefix}-*",
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:${local.name_prefix}-*",
    ]
  }
}

resource "aws_iam_user" "project_owner" {
  name = var.iam_user_name

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "project_owner" {
  name        = "${local.name_prefix}-projectowner-policy"
  description = "Scoped permissions for the ${var.project_name} project owner to manage ${var.environment} infrastructure"
  policy      = data.aws_iam_policy_document.project_owner.json

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_user_policy_attachment" "project_owner" {
  user       = aws_iam_user.project_owner.name
  policy_arn = aws_iam_policy.project_owner.arn
}
