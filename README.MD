# AWS Cost Analysis Agent - Terraform Deployment

An intelligent AWS cost analysis tool powered by Amazon Bedrock (Claude) that helps you understand and optimize your AWS spending through natural language conversations.

## 🏗️ Architecture

```
User → API Gateway → Lambda Function → AWS Cost Explorer API
                          ↓
                    Bedrock (Claude)
                          ↓
                    Cost Insights & Recommendations
```

## 📋 Prerequisites

Before deploying, ensure you have:

- [x] AWS Account with administrator access
- [x] [Terraform](https://www.terraform.io/downloads) >= 1.0 installed
- [x] AWS CLI configured (`aws configure`)
- [x] **Cost Explorer enabled** (wait 24 hours for initial data)
- [x] **Bedrock model access enabled** (Claude 3.5 Sonnet)

### Enable Cost Explorer

```bash
# Check if Cost Explorer is accessible
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost

# If error, enable via AWS Console:
# Console → Cost Management → Cost Explorer → Enable Cost Explorer
```

### Enable Bedrock Model Access

1. Go to AWS Console → Amazon Bedrock
2. Navigate to "Model access" in left sidebar
3. Click "Manage model access"
4. Select **"Claude 3.5 Sonnet v2"**
5. Click "Request model access"
6. Wait for approval (usually instant)

## 📁 Project Structure

```
aws-cost-analysis-agent/
├── main.tf                      # Main Terraform configuration
├── variables.tf                 # Variable definitions
├── outputs.tf                   # Output definitions
├── terraform.tfvars.example     # Example variables file
├── lambda/
│   └── lambda_function.py       # Lambda function code
└── README.md                    # This file
```

## 🚀 Quick Start

### Step 1: Clone and Setup

```bash
# Create project directory
mkdir aws-cost-analysis-agent
cd aws-cost-analysis-agent

# Create the Lambda directory
mkdir lambda

# Copy all Terraform files (main.tf, variables.tf, outputs.tf)
# Copy lambda_function.py to lambda/ directory
```

### Step 2: Configure Variables

```bash
# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your preferences
nano terraform.tfvars
```

**Key Configuration Options:**

```hcl
# Basic Configuration
aws_region     = "us-east-1"
project_name   = "aws-cost-analysis-agent"
environment    = "prod"

# API Security (optional)
enable_api_key = true  # Require API key for requests

# Daily Reports (optional)
enable_daily_reports  = true
daily_report_schedule = "cron(0 9 * * ? *)"  # 9 AM UTC

# SNS Alerts (optional)
enable_sns_alerts = true
alert_email       = "your-email@example.com"
```

### Step 3: Deploy with Terraform

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply

# Confirm with: yes
```

### Step 4: Test the Deployment

After deployment, Terraform will output test commands:

```bash
# Test Lambda directly
aws lambda invoke \
  --function-name aws-cost-analysis-agent-function \
  --payload '{"body":"{\"query\":\"What are my top spending services?\"}"}' \
  response.json && cat response.json

# Test via API Gateway
curl -X POST https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/prod/analyze \
  -H "Content-Type: application/json" \
  -d '{"query": "What are my top spending services?"}'

# If API key enabled:
curl -X POST https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/prod/analyze \
  -H "Content-Type: application/json" \
  -H "x-api-key: YOUR-API-KEY" \
  -d '{"query": "What are my top spending services?"}'

# View logs
aws logs tail /aws/lambda/aws-cost-analysis-agent-function --follow
```

## 📊 Features

### 1. **Natural Language Queries**

Ask questions in plain English:
- "What are my top 5 spending services this month?"
- "Show me my daily costs for the last week"
- "What's my cost forecast for next month?"
- "How can I reduce my EC2 costs?"
- "Compare costs from last week to this week"

### 2. **AI-Powered Insights**

Claude analyzes your AWS spending and provides:
- Detailed service breakdown
- Cost trends and anomalies
- Optimization recommendations
- Budget predictions

### 3. **Flexible Deployment Options**

Choose what features you need:

| Feature | Variable | Default | Description |
|---------|----------|---------|-------------|
| API Key Auth | `enable_api_key` | false | Require API key for requests |
| Daily Reports | `enable_daily_reports` | false | Automated daily cost summaries |
| SNS Alerts | `enable_sns_alerts` | false | Email notifications for anomalies |

## 🔧 Configuration Options

### API Gateway Settings

```hcl
# Rate limiting
api_quota_limit = 1000  # Requests per day
api_burst_limit = 100   # Burst requests
api_rate_limit  = 50    # Requests per second
```

### Bedrock Model Selection

```hcl
# Choose your model (in terraform.tfvars)
bedrock_model_id = "anthropic.claude-3-5-sonnet-20241022-v2:0"  # Recommended

# Other options:
# "anthropic.claude-3-sonnet-20240229-v1:0"
# "anthropic.claude-3-haiku-20240307-v1:0"
```

### CloudWatch Logs Retention

```hcl
log_retention_days = 7  # Keep logs for 7 days
```

### Daily Reports Schedule

```hcl
# Cron expressions (UTC time)
daily_report_schedule = "cron(0 9 * * ? *)"   # 9 AM UTC daily
daily_report_schedule = "cron(0 17 * * ? *)"  # 5 PM UTC daily
daily_report_schedule = "cron(0 0 * * MON *)" # Monday midnight
```

## 📖 Usage Examples

### Example 1: Cost Analysis

```bash
curl -X POST $API_ENDPOINT \
  -H "Content-Type: application/json" \
  -d '{"query": "What are my AWS costs today?"}'
```

**Response:**
```json
{
  "query": "What are my AWS costs today?",
  "response": "Based on your AWS cost data for today:\n\nYour total spending so far is $127.45, broken down as follows:\n\n1. **Amazon EC2**: $78.32 - Your primary compute costs\n2. **Amazon S3**: $23.18 - Storage costs\n3. **Amazon RDS**: $15.67 - Database services\n4. **AWS Lambda**: $10.28 - Serverless compute\n\nCompared to yesterday ($115.23), you're tracking 10.6% higher...",
  "timestamp": "2025-01-15T14:30:22.123456",
  "model": "anthropic.claude-3-5-sonnet-20241022-v2:0"
}
```

### Example 2: Cost Optimization

```bash
curl -X POST $API_ENDPOINT \
  -H "Content-Type: application/json" \
  -d '{"query": "How can I reduce my costs?"}'
```

### Example 3: Service-Specific Query

```bash
curl -X POST $API_ENDPOINT \
  -H "Content-Type: application/json" \
  -d '{"query": "Show me only my S3 costs and suggest optimizations"}'
```

## 🔒 Security Best Practices

### 1. Enable API Key Authentication

```hcl
# In terraform.tfvars
enable_api_key = true
```

Then retrieve the API key:
```bash
terraform output -raw api_key
```

### 2. Restrict API Access with AWS WAF (Optional)

Add WAF rules to your API Gateway:

```hcl
resource "aws_wafv2_web_acl" "api_waf" {
  name  = "${var.project_name}-waf"
  scope = "REGIONAL"
  
  default_action {
    allow {}
  }
  
  rule {
    name     = "RateLimitRule"
    priority = 1
    
    action {
      block {}
    }
    
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name               = "RateLimitRule"
      sampled_requests_enabled  = true
    }
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name               = "${var.project_name}-waf"
    sampled_requests_enabled  = true
  }
}
```

### 3. Use VPC Endpoints for Private Access

```hcl
resource "aws_vpc_endpoint" "bedrock" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.us-east-1.bedrock-runtime"
  vpc_endpoint_type = "Interface"
  
  subnet_ids = var.private_subnet_ids
  
  security_group_ids = [aws_security_group.bedrock_endpoint.id]
}
```

### 4. Enable X-Ray Tracing

X-Ray is already enabled in the Terraform configuration for API Gateway. To view traces:

```bash
# View service map
aws xray get-service-graph --start-time $(date -d '1 hour ago' +%s) --end-time $(date +%s)
```

## 📈 Monitoring & Logging

### View Lambda Logs

```bash
# Real-time logs
aws logs tail /aws/lambda/aws-cost-analysis-agent-function --follow

# Last hour
aws logs tail /aws/lambda/aws-cost-analysis-agent-function --since 1h

# Search for errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/aws-cost-analysis-agent-function \
  --filter-pattern "ERROR"
```

### CloudWatch Metrics

Key metrics to monitor:

- **Lambda Invocations**: `AWS/Lambda - Invocations`
- **Lambda Errors**: `AWS/Lambda - Errors`
- **Lambda Duration**: `AWS/Lambda - Duration`
- **API Gateway Requests**: `AWS/ApiGateway - Count`
- **API Gateway Latency**: `AWS/ApiGateway - Latency`

### Create CloudWatch Dashboard

```bash
aws cloudwatch put-dashboard \
  --dashboard-name "CostAgentMonitoring" \
  --dashboard-body file://dashboard.json
```

## 💰 Cost Estimation

### Monthly Cost Breakdown:

| Service | Usage | Estimated Cost |
|---------|-------|----------------|
| Lambda | 1,000 invocations | ~$0.20 |
| API Gateway | 1,000 requests | ~$3.50 |
| Cost Explorer API | 30 requests* | ~$0.30 |
| Bedrock (Claude) | ~100K tokens | ~$0.30 |
| CloudWatch Logs | 1GB | ~$0.50 |
| **Total** | | **~$4.80/month** |

*First request per day is free

### Cost Optimization Tips:

1. **Cache Cost Explorer responses** for 1-2 hours
2. **Use Lambda reserved concurrency** for predictable workloads
3. **Enable S3 lifecycle policies** for logs
4. **Set CloudWatch Logs retention** to 7 days
5. **Use API Gateway caching** for frequently asked queries

## 🔧 Troubleshooting

### Issue: "Cost Explorer is not enabled"

**Solution:**
```bash
# Enable via AWS Console
# Console → Cost Management → Cost Explorer → Enable Cost Explorer
# Wait 24 hours for initial data collection
```

### Issue: "Access denied for Bedrock"

**Solution:**
1. Check Bedrock model access is enabled
2. Verify IAM role has `bedrock:InvokeModel` permission
3. Ensure correct model ID in variables

```bash
# Check IAM policy
aws iam get-role-policy \
  --role-name aws-cost-analysis-agent-lambda-role \
  --policy-name aws-cost-analysis-agent-lambda-policy
```

### Issue: "No cost data available"

**Possible causes:**
- Cost Explorer needs 24 hours for initial data
- No AWS resource usage to track
- IAM permissions missing

**Solution:**
```bash
# Verify Cost Explorer access
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost
```

### Issue: Lambda timeout

**Solution:**
```hcl
# In main.tf, increase timeout
resource "aws_lambda_function" "cost_agent" {
  timeout = 120  # Increase from 60 to 120 seconds
}

# Apply changes
terraform apply
```

### Issue: API Gateway 403 Forbidden

**Solution:**
```bash
# If API key enabled, include it in request
curl -X POST $API_ENDPOINT \
  -H "x-api-key: $(terraform output -raw api_key)" \
  -H "Content-Type: application/json" \
  -d '{"query": "test"}'
```

## 🔄 Updates & Maintenance

### Update Lambda Code

```bash
# Modify lambda/lambda_function.py
# Then apply changes
terraform apply
```

### Update Terraform Configuration

```bash
# Modify main.tf, variables.tf, etc.
terraform plan
terraform apply
```

### Rotate API Key

```bash
# Force recreation of API key
terraform taint 'aws_api_gateway_api_key.api_key[0]'
terraform apply

# Get new key
terraform output -raw api_key
```

## 🧹 Cleanup & Destruction

### Remove All Resources

```bash
# Preview destruction
terraform plan -destroy

# Destroy all resources
terraform destroy

# Confirm with: yes
```

### Partial Cleanup

```bash
# Remove specific resources
terraform destroy -target=aws_api_gateway_rest_api.cost_api
terraform destroy -target=aws_lambda_function.cost_agent
```

### Manual Cleanup (if Terraform fails)

```bash
# Delete Lambda
aws lambda delete-function --function-name aws-cost-analysis-agent-function

# Delete API Gateway
API_ID=$(aws apigateway get-rest-apis --query 'items[?name==`aws-cost-analysis-agent-api`].id' --output text)
aws apigateway delete-rest-api --rest-api-id $API_ID

# Delete IAM role
aws iam delete-role-policy \
  --role-name aws-cost-analysis-agent-lambda-role \
  --policy-name aws-cost-analysis-agent-lambda-policy
aws iam delete-role --role-name aws-cost-analysis-agent-lambda-role

# Delete CloudWatch Logs
aws logs delete-log-group --log-group-name /aws/lambda/aws-cost-analysis-agent-function
```

## 📚 Additional Resources

- [AWS Cost Explorer API Documentation](https://docs.aws.amazon.com/cost-management/latest/APIReference/API_Operations_AWS_Cost_Explorer_Service.html)
- [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Claude API Documentation](https://docs.anthropic.com/claude/reference/getting-started-with-the-api)

## 🤝 Contributing

Contributions welcome! Feel free to:
- Report bugs
- Suggest features
- Submit pull requests
- Improve documentation

## 📝 License

MIT License - free to use for personal or commercial purposes.

---

## 🎯 Quick Reference

### Essential Commands

```bash
# Deploy
terraform init && terraform apply

# Test
terraform output test_lambda_command | bash

# Monitor
terraform output view_logs_command | bash

# Update
terraform apply

# Destroy
terraform destroy
```

### Get Outputs

```bash
# API endpoint
terraform output api_gateway_url

# API key (if enabled)
terraform output -raw api_key

# All outputs
terraform output
```

---

**Need Help?** Check the Troubleshooting section or review AWS CloudWatch Logs for detailed error messages.