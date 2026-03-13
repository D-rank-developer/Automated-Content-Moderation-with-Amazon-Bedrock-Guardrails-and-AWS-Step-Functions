resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  suffix = var.name_suffix != "" ? var.name_suffix : random_string.suffix.result

  name_prefix = "${var.project_name}-${var.environment}-${local.suffix}"

  uploads_bucket_name = lower("${var.uploads_bucket_prefix}-${var.environment}-${local.suffix}")
  results_table_name  = "${var.results_table_name_prefix}-${var.environment}-${local.suffix}"
  review_topic_name   = "${var.review_topic_name_prefix}-${var.environment}-${local.suffix}"
  lambda_name         = "lambda-${local.name_prefix}"
  event_rule_name     = "s3-object-created-${local.name_prefix}"
  log_group_name      = "/aws/lambda/${local.lambda_name}"

  common_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "content-moderation"
  }, var.tags)
}

resource "aws_s3_bucket" "uploads" {
  bucket = local.uploads_bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    id     = "transition-old-objects"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_notification" "uploads" {
  bucket      = aws_s3_bucket.uploads.id
  eventbridge = true
}

resource "aws_dynamodb_table" "moderation_results" {
  name         = local.results_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "object_key"

  attribute {
    name = "object_key"
    type = "S"
  }

  tags = local.common_tags
}

resource "aws_sns_topic" "review" {
  name = local.review_topic_name
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.review_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.review.arn
  protocol  = "email"
  endpoint  = var.review_email
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = local.log_group_name
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_iam_role" "lambda" {
  name = "role-${local.name_prefix}-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda" {
  name = "policy-${local.name_prefix}-lambda"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.uploads.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.moderation_results.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.review.arn
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:ApplyGuardrail"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rekognition:DetectModerationLabels"
        ]
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "moderator_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/moderate.py"
  output_path = "${path.module}/lambda/moderate.zip"
}

resource "aws_lambda_function" "moderator" {
  function_name = local.lambda_name
  role          = aws_iam_role.lambda.arn
  handler       = "moderate.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60
  memory_size   = 512

  filename         = data.archive_file.moderator_zip.output_path
  source_code_hash = data.archive_file.moderator_zip.output_base64sha256

  environment {
    variables = {
      RESULTS_TABLE                = aws_dynamodb_table.moderation_results.name
      REVIEW_TOPIC_ARN             = aws_sns_topic.review.arn
      BEDROCK_GUARDRAIL_ID         = var.bedrock_guardrail_id
      BEDROCK_GUARDRAIL_VERSION    = var.bedrock_guardrail_version
      TEXT_REJECT_CONFIDENCES      = jsonencode(var.text_reject_confidences)
      IMAGE_REVIEW_MIN_CONFIDENCE  = tostring(var.image_review_min_confidence)
      IMAGE_REJECT_MIN_CONFIDENCE  = tostring(var.image_reject_min_confidence)
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = local.common_tags
}

resource "aws_cloudwatch_event_rule" "s3_created" {
  name = local.event_rule_name

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.uploads.bucket]
      }
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.s3_created.name
  target_id = "moderation-lambda"
  arn       = aws_lambda_function.moderator.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.moderator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_created.arn
}