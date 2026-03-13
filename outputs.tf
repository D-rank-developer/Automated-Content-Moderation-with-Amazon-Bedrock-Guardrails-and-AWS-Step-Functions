output "uploads_bucket_name" {
  value = aws_s3_bucket.uploads.bucket
}

output "results_table_name" {
  value = aws_dynamodb_table.moderation_results.name
}

output "review_topic_arn" {
  value = aws_sns_topic.review.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.moderator.function_name
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.s3_created.name
}

output "validation_commands" {
  value = {
    list_bucket_objects = "aws s3 ls s3://${aws_s3_bucket.uploads.bucket}/ --profile ${var.aws_profile} --region ${var.aws_region}"
    tail_lambda_logs    = "aws logs tail ${aws_cloudwatch_log_group.lambda.name} --follow --profile ${var.aws_profile} --region ${var.aws_region}"
    scan_results_table  = "aws dynamodb scan --table-name ${aws_dynamodb_table.moderation_results.name} --profile ${var.aws_profile} --region ${var.aws_region}"
  }
}