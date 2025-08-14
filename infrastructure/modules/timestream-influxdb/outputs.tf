output "influxdb_instance_id" {
  description = "The ID of the Timestream InfluxDB instance"
  value       = aws_timestreaminfluxdb_db_instance.main.id
}

output "influxdb_instance_arn" {
  description = "The ARN of the Timestream InfluxDB instance"
  value       = aws_timestreaminfluxdb_db_instance.main.arn
}

output "influxdb_endpoint" {
  description = "The connection endpoint for the InfluxDB instance"
  value       = aws_timestreaminfluxdb_db_instance.main.endpoint
}

output "influxdb_url" {
  description = "The full URL for InfluxDB connections (https://endpoint:8086)"
  value       = aws_timestreaminfluxdb_db_instance.main.endpoint != null ? "https://${aws_timestreaminfluxdb_db_instance.main.endpoint}:8086" : "pending"
}

output "influxdb_availability_zone" {
  description = "The availability zone of the InfluxDB instance"
  value       = aws_timestreaminfluxdb_db_instance.main.availability_zone
}

output "influxdb_security_group_id" {
  description = "The security group ID for InfluxDB access"
  value       = aws_security_group.influxdb_sg.id
}

output "influxdb_security_group_name" {
  description = "The security group name for InfluxDB access"
  value       = aws_security_group.influxdb_sg.name
}

output "admin_username" {
  description = "The admin username for InfluxDB"
  value       = var.admin_username
}

output "organization_name" {
  description = "The organization name in InfluxDB"
  value       = var.organization_name
}

output "bucket_name" {
  description = "The bucket name in InfluxDB"
  value       = var.bucket_name
}

output "credentials_secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret containing InfluxDB credentials"
  value       = aws_secretsmanager_secret.influxdb_credentials.arn
}

output "influx_auth_parameters_secret_arn" {
  description = "The AWS-generated secret ARN for InfluxDB authentication parameters"
  value       = aws_timestreaminfluxdb_db_instance.main.influx_auth_parameters_secret_arn
}