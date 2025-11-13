# AWS Configuration
aws_region     = "us-east-1"
bedrock_region = "us-east-1"

# Project Configuration
project_name = "aws-cost-analysis-agent"
environment  = "prod"

# Bedrock Model Configuration
bedrock_model_id = "us.anthropic.claude-3-5-sonnet-20241022-v2:0"

# Custom Domain Configuration (Optional)
# Choose ONE of the following options:

# Option 1: Create NEW hosted zone (if you don't have one)
# Uncomment these lines and add your domain:
create_hosted_zone = true
domain_name        = "costexplorerbot.work.gd"
route53_zone_id    = ""  # Leave empty when creating new zone

# Option 2: Use EXISTING hosted zone (if you already have one)
# Uncomment these lines:
# create_hosted_zone = false
# domain_name        = "cost-analyzer.yourdomain.com"
# route53_zone_id    = "Z1234567890ABC"  # Your existing zone ID

# Option 3: No custom domain (use S3 URL directly)
# create_hosted_zone = false
# domain_name        = "costexplorerbot.work.gd"
# route53_zone_id    = ""

# To find your existing Zone ID, run:
# aws route53 list-hosted-zones --query 'HostedZones[*].[Name,Id]' --output table

# Logging Configuration
log_retention_days = 7

# API Gateway Configuration
api_stage_name = "prod"

# API Authentication (set to true to require API key)
enable_api_key = false

# API Rate Limiting
api_quota_limit = 1000  # Requests per day
api_burst_limit = 100   # Burst requests
api_rate_limit  = 50    # Requests per second

# SNS Alerts (optional)
enable_sns_alerts = false
alert_email       = ""  # Add your email if enabling alerts

# Daily Reports (optional)
enable_daily_reports  = false
daily_report_schedule = "cron(0 9 * * ? *)"  # 9 AM UTC daily

# Additional Tags
tags = {
  Owner       = "DevOps Team"
  CostCenter  = "Engineering"
  Application = "Cost Analysis"
}