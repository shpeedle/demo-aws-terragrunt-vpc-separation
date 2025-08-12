output "repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.lambda_repo.repository_url
}

output "repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.lambda_repo.name
}

output "registry_id" {
  description = "ECR registry ID"
  value       = aws_ecr_repository.lambda_repo.registry_id
}