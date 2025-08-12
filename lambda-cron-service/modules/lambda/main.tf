data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda_role" {
  name = "${var.environment}-lambda-cron-role"

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
  name        = "${var.environment}-lambda-cron-sg"
  description = "Security group for Lambda cron function"
  vpc_id      = var.vpc_config.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-lambda-cron-sg"
  }
}

resource "aws_lambda_function" "main" {
  package_type     = "Image"
  image_uri        = var.image_uri
  function_name    = "${var.environment}-lambda-cron-function"
  role            = aws_iam_role.lambda_role.arn
  timeout         = var.timeout
  memory_size     = var.memory_size

  environment {
    variables = merge(
      {
        ENVIRONMENT = var.environment
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

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc,
  ]
}

# EventBridge rule for hourly cron job
resource "aws_cloudwatch_event_rule" "hourly_cron" {
  name                = "${var.environment}-lambda-cron-hourly"
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
  name                       = "${var.environment}-work-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600  # 14 days
  
  tags = {
    Name = "${var.environment}-work-queue"
  }
}

# Dead Letter Queue for failed messages
resource "aws_sqs_queue" "work_queue_dlq" {
  name = "${var.environment}-work-queue-dlq"
  
  tags = {
    Name = "${var.environment}-work-queue-dlq"
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
  package_type     = "Image"
  image_uri        = var.worker_image_uri != null ? var.worker_image_uri : var.image_uri
  function_name    = "${var.environment}-lambda-worker-function"
  role            = aws_iam_role.worker_lambda_role.arn
  timeout         = var.worker_timeout != null ? var.worker_timeout : var.timeout
  memory_size     = var.worker_memory_size != null ? var.worker_memory_size : var.memory_size

  environment {
    variables = merge(
      {
        ENVIRONMENT = var.environment
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

  depends_on = [
    aws_iam_role_policy_attachment.worker_lambda_basic,
    aws_iam_role_policy_attachment.worker_lambda_vpc,
  ]
}

# IAM role for worker Lambda function
resource "aws_iam_role" "worker_lambda_role" {
  name = "${var.environment}-lambda-worker-role"

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
  name = "${var.environment}-lambda-sqs-policy"
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
  name = "${var.environment}-lambda-worker-sqs-policy"
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