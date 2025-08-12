data "aws_caller_identity" "current" {}

# IAM role for Step Functions
resource "aws_iam_role" "step_functions_role" {
  name = "${var.environment}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

# Policy for Step Functions to invoke Lambda functions
resource "aws_iam_role_policy" "step_functions_policy" {
  name = "${var.environment}-step-functions-policy"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          for func in aws_lambda_function.step_functions :
          func.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "${var.environment}-step-lambda-role"

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

# Security group for Lambda functions (when VPC is used)
resource "aws_security_group" "lambda_sg" {
  count       = var.vpc_config != null ? 1 : 0
  name        = "${var.environment}-step-lambda-sg"
  description = "Security group for Step Functions Lambda functions"
  vpc_id      = var.vpc_config.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-step-lambda-sg"
  }
}

# Lambda functions for Step Functions workflow
resource "aws_lambda_function" "step_functions" {
  for_each = var.lambda_functions

  package_type     = "Image"
  image_uri        = each.value.image_uri
  function_name    = "${var.environment}-${each.key}"
  role            = aws_iam_role.lambda_role.arn
  timeout         = each.value.timeout
  memory_size     = each.value.memory_size

  environment {
    variables = merge(
      {
        ENVIRONMENT = var.environment
      },
      each.value.environment_variables
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

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/stepfunctions/${var.environment}-processing-workflow"
  retention_in_days = 14
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "processing_workflow" {
  name     = "${var.environment}-processing-workflow"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = templatefile("${path.module}/state_machine.json", {
    processor_function_arn = aws_lambda_function.step_functions["step-processor"].arn
    validator_function_arn = aws_lambda_function.step_functions["step-validator"].arn
    notifier_function_arn  = aws_lambda_function.step_functions["step-notifier"].arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = {
    Name = "${var.environment}-processing-workflow"
  }
}