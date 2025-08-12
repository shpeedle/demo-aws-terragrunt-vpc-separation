output "repository_urls" {
  description = "ECR repository URLs for Lambda functions"
  value = {
    for name, repo in aws_ecr_repository.lambda_step_functions : 
    name => repo.repository_url
  }
}

output "repository_arns" {
  description = "ECR repository ARNs for Lambda functions"
  value = {
    for name, repo in aws_ecr_repository.lambda_step_functions : 
    name => repo.arn
  }
}