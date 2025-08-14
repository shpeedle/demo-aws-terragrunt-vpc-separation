# Random password for InfluxDB admin user (alphanumeric only)
resource "random_password" "influxdb_password" {
  length  = 16
  special = false
  upper   = true
  lower   = true
  numeric = true
}

# Security group for InfluxDB access
resource "aws_security_group" "influxdb_sg" {
  name_prefix = "${var.environment}-timestream-influxdb-sg-"
  description = "Security group for Timestream InfluxDB instance"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  # InfluxDB HTTP API port
  ingress {
    from_port       = 8086
    to_port         = 8086
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
    description     = "InfluxDB HTTP API access"
  }

  # Allow ingress from VPC CIDR for internal access
  ingress {
    from_port   = 8086
    to_port     = 8086
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "InfluxDB access from VPC"
  }

  # Allow public access when publicly_accessible is true (for token generation)
  dynamic "ingress" {
    for_each = var.publicly_accessible ? [1] : []
    content {
      from_port   = 8086
      to_port     = 8086
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "InfluxDB public access for UI/token generation"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.environment}-timestream-influxdb-sg"
  }
}

# AWS Secrets Manager secret for InfluxDB credentials
resource "aws_secretsmanager_secret" "influxdb_credentials" {
  name_prefix             = "${var.environment}-timestream-influxdb-credentials-"
  description             = "Credentials for Timestream InfluxDB instance"
  recovery_window_in_days = var.secret_recovery_window

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.environment}-timestream-influxdb-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "influxdb_credentials" {
  secret_id = aws_secretsmanager_secret.influxdb_credentials.id
  secret_string = jsonencode({
    username     = var.admin_username
    password     = random_password.influxdb_password.result
    organization = var.organization_name
    bucket       = var.bucket_name
    token        = "PLACEHOLDER_TOKEN_NEEDS_TO_BE_CREATED_VIA_INFLUXDB_CLI_OR_UI"
  })
}

# Timestream for InfluxDB instance
resource "aws_timestreaminfluxdb_db_instance" "main" {
  name                   = "${var.environment}-timestream-influxdb"
  db_instance_type       = var.db_instance_type
  vpc_subnet_ids         = var.subnet_ids
  vpc_security_group_ids = [aws_security_group.influxdb_sg.id]
  
  username     = var.admin_username
  password     = random_password.influxdb_password.result
  organization = var.organization_name
  bucket       = var.bucket_name
  
  allocated_storage                = var.allocated_storage
  db_storage_type                  = var.db_storage_type
  deployment_type                  = var.deployment_type
  publicly_accessible            = var.publicly_accessible

  lifecycle {
    prevent_destroy = false  # Temporarily disabled to allow publicly_accessible change
    ignore_changes = [
      password,  # Prevent drift from password changes
    ]
  }

  # Optional log delivery configuration
  dynamic "log_delivery_configuration" {
    for_each = var.enable_logging ? [1] : []
    content {
      s3_configuration {
        enabled     = true
        bucket_name = var.log_bucket_name
      }
    }
  }

  tags = {
    Name        = "${var.environment}-timestream-influxdb"
    Environment = var.environment
  }

  depends_on = [
    aws_security_group.influxdb_sg
  ]
}