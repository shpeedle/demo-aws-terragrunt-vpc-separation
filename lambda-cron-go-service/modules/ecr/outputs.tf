output "repository_url" {
  description = "ECR repository URL for main cron service"
  value       = aws_ecr_repository.lambda_repo.repository_url
}

output "repository_name" {
  description = "ECR repository name for main cron service"
  value       = aws_ecr_repository.lambda_repo.name
}

output "worker_repository_url" {
  description = "ECR repository URL for worker lambda"
  value       = aws_ecr_repository.worker_repo.repository_url
}

output "worker_repository_name" {
  description = "ECR repository name for worker lambda"
  value       = aws_ecr_repository.worker_repo.name
}

output "registry_id" {
  description = "ECR registry ID"
  value       = aws_ecr_repository.lambda_repo.registry_id
}