# Lambda Cron Go Service Module with VPC ENI Cleanup
#
# This module includes several measures to prevent Lambda VPC ENI cleanup issues:
# 1. Extended timeouts (45m) for Lambda function deletion
# 2. Automated ENI cleanup via destroy-time provisioner
# 3. Proper dependency ordering to ensure security groups are deleted last
# 4. Lifecycle rules to prevent premature resource destruction
#
# The destroy-time provisioner handles the common issue where Lambda VPC ENIs
# remain attached after function deletion, preventing security group cleanup.

data "aws_caller_identity" "current" {}


resource "aws_iam_role" "lambda_role" {
  name = "${var.environment}-${var.project_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.vpc_config != null ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_security_group" "lambda_sg" {
  count       = var.vpc_config != null ? 1 : 0
  name        = "${var.environment}-${var.project_name}-sg"
  description = "Security group for Lambda cron function"
  vpc_id      = var.vpc_config.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Lifecycle management to prevent destruction issues
  lifecycle {
    create_before_destroy = true
  }

  # Dependencies to ensure proper destroy order
  depends_on = [
    aws_iam_role.lambda_role,
    aws_iam_role.worker_lambda_role
  ]

  tags = {
    Name = "${var.environment}-${var.project_name}-sg"
  }
}

resource "aws_lambda_function" "main" {
  package_type  = "Image"
  image_uri     = var.image_uri
  function_name = "${var.environment}-${var.project_name}-function"
  role          = aws_iam_role.lambda_role.arn
  timeout       = var.timeout
  memory_size   = var.memory_size

  environment {
    variables = merge(
      {
        ENVIRONMENT   = var.environment
        SQS_QUEUE_URL = aws_sqs_queue.work_queue.url
      },
      var.environment_variables
    )
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = [aws_security_group.lambda_sg[0].id]
    }
  }

  # Extended timeouts to handle ENI cleanup delays
  timeouts {
    create = "15m"
    update = "15m"
    delete = "45m"
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc,
  ]
}

# ENI cleanup resource to handle Lambda VPC ENI deletion issues
resource "null_resource" "eni_cleanup" {
  count = var.vpc_config != null ? 1 : 0

  # Store values as triggers that can be used during destroy
  triggers = {
    region           = var.aws_region != null ? var.aws_region : "us-east-1"
    environment      = var.environment
    project_name     = var.project_name
    vpc_id          = var.vpc_config != null ? var.vpc_config.vpc_id : ""
    main_function   = "${var.environment}-${var.project_name}-function"
    worker_function = "${var.environment}-${replace(var.project_name, "service", "worker")}-function"
  }

  # This provisioner runs during destroy to clean up Lambda-created ENIs
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Starting ENI cleanup for Lambda functions..."
      
      # Wait for Lambda functions to be deleted first
      sleep 60
      
      # Use trigger values instead of resource references
      REGION="${self.triggers.region}"
      VPC_ID="${self.triggers.vpc_id}"
      MAIN_FUNCTION="${self.triggers.main_function}"
      WORKER_FUNCTION="${self.triggers.worker_function}"
      
      echo "Looking for ENIs associated with Lambda functions: $MAIN_FUNCTION, $WORKER_FUNCTION"
      echo "In VPC: $VPC_ID"
      
      # Get ENIs associated with the VPC and Lambda functions
      ENI_IDS=$(aws ec2 describe-network-interfaces \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'NetworkInterfaces[?contains(Description, `AWS Lambda VPC ENI`) && (contains(Description, `'$MAIN_FUNCTION'`) || contains(Description, `'$WORKER_FUNCTION'`))].NetworkInterfaceId' \
        --output text \
        --region $REGION 2>/dev/null || echo "")
      
      if [ -n "$ENI_IDS" ] && [ "$ENI_IDS" != "None" ]; then
        echo "Found Lambda ENIs to cleanup: $ENI_IDS"
        
        # Multiple attempts with increasing wait times
        for attempt in 1 2 3; do
          echo "Cleanup attempt $attempt..."
          for ENI_ID in $ENI_IDS; do
            echo "Attempting to delete ENI: $ENI_ID"
            if aws ec2 delete-network-interface --network-interface-id $ENI_ID --region $REGION 2>/dev/null; then
              echo "Successfully deleted ENI: $ENI_ID"
            else
              echo "ENI $ENI_ID still in use or already deleted"
            fi
          done
          
          # Wait longer between attempts
          if [ $attempt -lt 3 ]; then
            echo "Waiting 60 seconds before next attempt..."
            sleep 60
          fi
        done
        
        echo "ENI cleanup completed"
      else
        echo "No Lambda ENIs found for cleanup"
      fi
    EOT
  }

  # This ensures the cleanup runs before other resources are destroyed
  depends_on = [
    aws_lambda_function.main,
    aws_lambda_function.worker
  ]
}

# EventBridge rule for hourly cron job
resource "aws_cloudwatch_event_rule" "hourly_cron" {
  name                = "${var.environment}-${var.project_name}-hourly"
  description         = "Trigger lambda function every hour"
  schedule_expression = "rate(1 hour)"
}

# EventBridge target to invoke Lambda function
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.hourly_cron.name
  target_id = "LambdaCronTarget"
  arn       = aws_lambda_function.main.arn
}

# Permission for EventBridge to invoke Lambda function
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.hourly_cron.arn
}

# SQS Queue for work items
resource "aws_sqs_queue" "work_queue" {
  name                       = "${var.environment}-go-work-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600 # 14 days

  tags = {
    Name = "${var.environment}-go-work-queue"
  }
}

# Dead Letter Queue for failed messages
resource "aws_sqs_queue" "work_queue_dlq" {
  name = "${var.environment}-go-work-queue-dlq"

  tags = {
    Name = "${var.environment}-go-work-queue-dlq"
  }
}

# Queue policy for redrive to DLQ
resource "aws_sqs_queue_redrive_policy" "work_queue_redrive" {
  queue_url = aws_sqs_queue.work_queue.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.work_queue_dlq.arn
    maxReceiveCount     = 3
  })
}

# Worker Lambda Function
resource "aws_lambda_function" "worker" {
  package_type  = "Image"
  image_uri     = var.worker_image_uri != null ? var.worker_image_uri : var.image_uri
  function_name = "${var.environment}-${replace(var.project_name, "service", "worker")}-function"
  role          = aws_iam_role.worker_lambda_role.arn
  timeout       = var.worker_timeout != null ? var.worker_timeout : var.timeout
  memory_size   = var.worker_memory_size != null ? var.worker_memory_size : var.memory_size

  environment {
    variables = merge(
      {
        ENVIRONMENT   = var.environment
        SQS_QUEUE_URL = aws_sqs_queue.work_queue.url
      },
      var.environment_variables
    )
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = [aws_security_group.lambda_sg[0].id]
    }
  }

  # Extended timeouts to handle ENI cleanup delays
  timeouts {
    create = "15m"
    update = "15m"
    delete = "45m"
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_lambda_basic,
    aws_iam_role_policy_attachment.worker_lambda_vpc,
  ]
}

# IAM role for worker Lambda function
resource "aws_iam_role" "worker_lambda_role" {
  name = "${var.environment}-${replace(var.project_name, "service", "worker")}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "worker_lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.worker_lambda_role.name
}

resource "aws_iam_role_policy_attachment" "worker_lambda_vpc" {
  count      = var.vpc_config != null ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.worker_lambda_role.name
}

# SQS Event Source Mapping for worker Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.work_queue.arn
  function_name    = aws_lambda_function.worker.arn
  batch_size       = var.sqs_batch_size != null ? var.sqs_batch_size : 1

  depends_on = [aws_iam_role_policy.sqs_permissions]
}

# SQS permissions for both Lambda functions
resource "aws_iam_role_policy" "sqs_permissions" {
  name = "${var.environment}-${var.project_name}-sqs-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = [
          aws_sqs_queue.work_queue.arn
        ]
      }
    ]
  })
}

# SQS permissions for worker Lambda function
resource "aws_iam_role_policy" "worker_sqs_permissions" {
  name = "${var.environment}-${replace(var.project_name, "service", "worker")}-sqs-policy"
  role = aws_iam_role.worker_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [
          aws_sqs_queue.work_queue.arn
        ]
      }
    ]
  })
}

# IAM policy for InfluxDB Secrets Manager access (main Lambda)
resource "aws_iam_role_policy" "influxdb_secrets_permissions" {
  name = "${var.environment}-${var.project_name}-secrets-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.influxdb_secret_arn
        ]
      }
    ]
  })
}

# IAM policy for InfluxDB Secrets Manager access (worker Lambda)
resource "aws_iam_role_policy" "worker_influxdb_secrets_permissions" {
  name = "${var.environment}-${replace(var.project_name, "service", "worker")}-secrets-policy"
  role = aws_iam_role.worker_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.influxdb_secret_arn
        ]
      }
    ]
  })
}