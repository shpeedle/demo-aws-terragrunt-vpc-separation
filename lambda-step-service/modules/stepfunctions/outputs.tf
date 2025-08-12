output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.processing_workflow.arn
}

output "state_machine_name" {
  description = "Name of the Step Functions state machine"
  value       = aws_sfn_state_machine.processing_workflow.name
}

output "lambda_function_arns" {
  description = "ARNs of Lambda functions"
  value = {
    for name, func in aws_lambda_function.step_functions :
    name => func.arn
  }
}

output "lambda_function_names" {
  description = "Names of Lambda functions"
  value = {
    for name, func in aws_lambda_function.step_functions :
    name => func.function_name
  }
}