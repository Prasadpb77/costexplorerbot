variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "aws-cost-analysis-agent"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "bedrock_model_id" {
  description = "Bedrock model ID to use"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "bedrock_region" {
  description = "AWS region for Bedrock service"
  type        = string
  default     = "us-east-1"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 7
}

variable "api_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "prod"
}

variable "enable_api_key" {
  description = "Enable API key authentication"
  type        = bool
  default     = false
}

variable "api_quota_limit" {
  description = "API daily quota limit (requests per day)"
  type        = number
  default     = 1000
}

variable "api_burst_limit" {
  description = "API burst limit (requests)"
  type        = number
  default     = 100
}

variable "api_rate_limit" {
  description = "API rate limit (requests per second)"
  type        = number
  default     = 50
}

variable "enable_sns_alerts" {
  description = "Enable SNS alerts for cost anomalies"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email address for cost alerts"
  type        = string
  default     = ""
}

variable "enable_daily_reports" {
  description = "Enable daily cost reports via EventBridge"
  type        = bool
  default     = false
}

variable "daily_report_schedule" {
  description = "Cron expression for daily reports (UTC)"
  type        = string
  default     = "cron(0 9 * * ? *)" # 9 AM UTC daily
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}