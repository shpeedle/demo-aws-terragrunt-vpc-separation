output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.main.arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.main.invoke_arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = aws_iam_role.lambda_role.arn
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.hourly_cron.arn
}

output "worker_lambda_function_name" {
  description = "Name of the worker Lambda function"
  value       = aws_lambda_function.worker.function_name
}

output "worker_lambda_function_arn" {
  description = "ARN of the worker Lambda function"
  value       = aws_lambda_function.worker.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS work queue"
  value       = aws_sqs_queue.work_queue.url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS work queue"
  value       = aws_sqs_queue.work_queue.arn
}

output "sqs_dlq_url" {
  description = "URL of the SQS dead letter queue"
  value       = aws_sqs_queue.work_queue_dlq.url
}

output "sqs_dlq_arn" {
  description = "ARN of the SQS dead letter queue"
  value       = aws_sqs_queue.work_queue_dlq.arn
}