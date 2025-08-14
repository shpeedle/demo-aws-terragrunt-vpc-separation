variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the InfluxDB instance will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group ingress rules"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the InfluxDB instance"
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "List of security group IDs allowed to access InfluxDB"
  type        = list(string)
  default     = []
}

variable "db_instance_type" {
  description = "The InfluxDB instance type"
  type        = string
  default     = "db.influx.medium"
  
  validation {
    condition = contains([
      "db.influx.medium",
      "db.influx.large", 
      "db.influx.xlarge",
      "db.influx.2xlarge",
      "db.influx.4xlarge",
      "db.influx.8xlarge",
      "db.influx.12xlarge",
      "db.influx.16xlarge"
    ], var.db_instance_type)
    error_message = "Instance type must be a valid InfluxDB instance type."
  }
}

variable "allocated_storage" {
  description = "The allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_storage_type" {
  description = "The storage type for the InfluxDB instance"
  type        = string
  default     = "InfluxIOIncludedT1"
}

variable "deployment_type" {
  description = "The deployment type (SINGLE_AZ or WITH_MULTIAZ_STANDBY)"
  type        = string
  default     = "SINGLE_AZ"
  
  validation {
    condition = contains([
      "SINGLE_AZ",
      "WITH_MULTIAZ_STANDBY"
    ], var.deployment_type)
    error_message = "Deployment type must be either SINGLE_AZ or WITH_MULTIAZ_STANDBY."
  }
}

variable "publicly_accessible" {
  description = "Whether the InfluxDB instance is publicly accessible"
  type        = bool
  default     = false
}


variable "admin_username" {
  description = "The admin username for InfluxDB"
  type        = string
  default     = "admin"
}

variable "organization_name" {
  description = "The initial organization name in InfluxDB"
  type        = string
}

variable "bucket_name" {
  description = "The initial bucket name in InfluxDB"
  type        = string
}

variable "enable_logging" {
  description = "Enable S3 logging for InfluxDB"
  type        = bool
  default     = false
}

variable "log_bucket_name" {
  description = "S3 bucket name for InfluxDB logs (required if enable_logging is true)"
  type        = string
  default     = ""
}

variable "secret_recovery_window" {
  description = "Number of days to retain secret after deletion"
  type        = number
  default     = 7
}