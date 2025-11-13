terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "AWS-Cost-Analysis-Agent"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Data source for AWS region
data "aws_region" "current" {}

# Archive the Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda_deployment.zip"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

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

# IAM Policy for Cost Explorer and Bedrock access
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage",
          "ce:GetCostForecast",
          "ce:GetDimensionValues",
          "ce:GetTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-5-sonnet-*",
          "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-text-premier-v1:0",
          "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-premier-v1:0",
          "arn:aws:bedrock:*::foundation-model/*",
          "arn:aws:bedrock:us-east-1:920013188018:inference-profile/us.anthropic.claude-3-5-sonnet-20241022-v2:0"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.project_name}-function"
  retention_in_days = var.log_retention_days
}

# Lambda Function
resource "aws_lambda_function" "cost_agent" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-function"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 60
  memory_size     = 512

  environment {
    variables = {
      BEDROCK_MODEL_ID = var.bedrock_model_id
      BEDROCK_REGION   = var.bedrock_region
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_log_group,
    aws_iam_role_policy.lambda_policy
  ]
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "cost_api" {
  name        = "${var.project_name}-api"
  description = "API for AWS Cost Analysis Agent"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Resource
resource "aws_api_gateway_resource" "analyze" {
  rest_api_id = aws_api_gateway_rest_api.cost_api.id
  parent_id   = aws_api_gateway_rest_api.cost_api.root_resource_id
  path_part   = "analyze"
}

# API Gateway Method (POST)
resource "aws_api_gateway_method" "post_analyze" {
  rest_api_id   = aws_api_gateway_rest_api.cost_api.id
  resource_id   = aws_api_gateway_resource.analyze.id
  http_method   = "POST"
  authorization = var.enable_api_key ? "API_KEY" : "NONE"
}

# API Gateway Integration with Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.cost_api.id
  resource_id             = aws_api_gateway_resource.analyze.id
  http_method             = aws_api_gateway_method.post_analyze.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.cost_agent.invoke_arn
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_agent.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.cost_api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.cost_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.analyze.id,
      aws_api_gateway_method.post_analyze.id,
      aws_api_gateway_integration.lambda_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.cost_api.id
  stage_name    = var.api_stage_name

  xray_tracing_enabled = false
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = var.log_retention_days
}

# API Key (if enabled)
resource "aws_api_gateway_api_key" "api_key" {
  count = var.enable_api_key ? 1 : 0
  name  = "${var.project_name}-api-key"
}

# Usage Plan (if API key enabled)
resource "aws_api_gateway_usage_plan" "usage_plan" {
  count = var.enable_api_key ? 1 : 0
  name  = "${var.project_name}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.cost_api.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }

  quota_settings {
    limit  = var.api_quota_limit
    period = "DAY"
  }

  throttle_settings {
    burst_limit = var.api_burst_limit
    rate_limit  = var.api_rate_limit
  }
}

# Usage Plan Key (if API key enabled)
resource "aws_api_gateway_usage_plan_key" "usage_plan_key" {
  count         = var.enable_api_key ? 1 : 0
  key_id        = aws_api_gateway_api_key.api_key[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.usage_plan[0].id
}

# SNS Topic for Cost Alerts (Optional)
resource "aws_sns_topic" "cost_alerts" {
  count = var.enable_sns_alerts ? 1 : 0
  name  = "${var.project_name}-alerts"
}

# SNS Topic Subscription (Optional)
resource "aws_sns_topic_subscription" "cost_alerts_email" {
  count     = var.enable_sns_alerts && var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.cost_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# EventBridge Rule for Daily Cost Report (Optional)
resource "aws_cloudwatch_event_rule" "daily_report" {
  count               = var.enable_daily_reports ? 1 : 0
  name                = "${var.project_name}-daily-report"
  description         = "Trigger daily cost analysis report"
  schedule_expression = var.daily_report_schedule
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  count     = var.enable_daily_reports ? 1 : 0
  rule      = aws_cloudwatch_event_rule.daily_report[0].name
  target_id = "TriggerLambda"
  arn       = aws_lambda_function.cost_agent.arn

  input = jsonencode({
    body = jsonencode({
      query = "Provide a daily cost summary report for yesterday with key insights and recommendations"
    })
  })
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  count         = var.enable_daily_reports ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_agent.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_report[0].arn
}