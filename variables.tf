variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Short project name"
  type        = string
  default     = "contentmod"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "demo"

  validation {
    condition     = contains(["dev", "staging", "prod", "demo"], var.environment)
    error_message = "environment must be one of dev, staging, prod, demo."
  }
}

variable "name_suffix" {
  description = "Optional fixed suffix; leave empty to auto-generate"
  type        = string
  default     = ""
}

variable "uploads_bucket_prefix" {
  description = "Base prefix for the uploads bucket"
  type        = string
  default     = "contentmod-uploads"
}

variable "results_table_name_prefix" {
  description = "Base prefix for the DynamoDB results table"
  type        = string
  default     = "contentmod-results"
}

variable "review_topic_name_prefix" {
  description = "Base prefix for the SNS review topic"
  type        = string
  default     = "contentmod-review"
}

variable "review_email" {
  description = "Optional email subscription for review notifications"
  type        = string
  default     = ""
}

variable "bedrock_guardrail_id" {
  description = "Existing Bedrock Guardrail ID"
  type        = string
}

variable "bedrock_guardrail_version" {
  description = "Bedrock Guardrail version, e.g. DRAFT or 1"
  type        = string
  default     = "DRAFT"
}

variable "text_reject_confidences" {
  description = "Guardrail confidence values that should auto-reject text"
  type        = list(string)
  default     = ["HIGH", "MEDIUM"]
}

variable "image_review_min_confidence" {
  description = "Minimum Rekognition confidence to flag an image for review"
  type        = number
  default     = 70
}

variable "image_reject_min_confidence" {
  description = "Minimum Rekognition confidence to auto-reject an image"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Extra tags"
  type        = map(string)
  default     = {}
}