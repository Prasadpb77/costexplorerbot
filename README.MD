# AWS Cost Analysis Agent

An intelligent AWS cost analysis tool with a web interface, powered by Amazon Bedrock (Claude) that helps you understand and optimize your AWS spending through natural language conversations.

## 🎯 Features

- 💬 **Interactive Web Interface** - Beautiful chat-based UI hosted on S3
- 🤖 **AI-Powered Analysis** - Uses Amazon Bedrock (Claude) for intelligent insights
- 📊 **Real-time Cost Data** - Fetches actual AWS spending from Cost Explorer
- 🔒 **Secure API** - Optional API key authentication
- ⚡ **Serverless** - Lambda + API Gateway + S3 hosting
- 🌐 **Custom Domain** - Optional Route53 integration
- 📱 **Responsive Design** - Works on desktop and mobile

## 🏗️ Architecture

```
User Browser → S3 Static Website (Custom Domain via Route53)
                     ↓
              API Gateway → Lambda → Cost Explorer API
                                          ↓
                                    Bedrock (Claude)
```

## 📋 Prerequisites

Before deploying:

1. **Terraform** >= 1.0 installed
2. **AWS CLI** configured with credentials
3. **Cost Explorer** enabled (wait 24 hours for initial data)
4. **Bedrock model access** enabled (Claude 3.5 Sonnet)
5. **Route53 Hosted Zone** (optional, if using custom domain)

### Enable Cost Explorer

```bash
# Check if accessible
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost

# If error, enable via AWS Console:
# Console → Cost Management → Cost Explorer → Enable
```

### Enable Bedrock Model Access

1. Go to AWS Console → Amazon Bedrock
2. Click "Model access" → "Manage model access"
3. Select **"Claude 3.5 Sonnet v2"**
4. Click "Request model access"

### Get Route53 Zone ID (Optional)

If you want to use a custom domain:

```bash
# List your hosted zones
aws route53 list-hosted-zones --query 'HostedZones[*].[Name,Id]' --output table

# Copy the Zone ID for your domain
```

## 🚀 Quick Deployment

### Step 1: Clone and Setup

```bash
# Create project directory
mkdir aws-cost-analysis-agent
cd aws-cost-analysis-agent

# Create required directories
mkdir frontend lambda
```

### Step 2: Create Files

Copy these files into your project:

```
aws-cost-analysis-agent/
├── frontend/
│   └── index.html              # Web interface
├── lambda/
│   └── lambda_function.py      # Lambda function
├── main.tf                     # Main infrastructure
├── s3-hosting.tf               # S3 + Route53
├── variables.tf                # Variables
├── outputs.tf                  # Outputs
├── terraform.tfvars            # Your config (create this)
└── README.md                   # This file
```

### Step 3: Configure

Create `terraform.tfvars`:

**Option A: Without Custom Domain (S3 URL only)**
```hcl
# Basic Configuration
aws_region   = "us-east-1"
project_name = "aws-cost-agent"
environment  = "prod"

# Bedrock
bedrock_model_id = "anthropic.claude-3-5-sonnet-20241022-v2:0"
bedrock_region   = "us-east-1"

# Leave domain settings empty
domain_name      = ""
route53_zone_id  = ""

# Security
enable_api_key = false  # Set true for production

# Optional Features
enable_sns_alerts    = false
enable_daily_reports = false
```

**Option B: With Custom Domain (Route53)**
```hcl
# Basic Configuration
aws_region   = "us-east-1"
project_name = "aws-cost-agent"
environment  = "prod"

# Bedrock
bedrock_model_id = "anthropic.claude-3-5-sonnet-20241022-v2:0"
bedrock_region   = "us-east-1"

# Custom Domain
domain_name      = "cost-analyzer.yourdomain.com"
route53_zone_id  = "Z1234567890ABC"

# Security
enable_api_key = false

# Optional Features
enable_sns_alerts    = false
enable_daily_reports = false
```

### Step 4: Deploy

```bash
# Initialize
terraform init

# Preview
terraform plan

# Deploy
terraform apply
```

### Step 5: Access Your Application

```bash
# Get the frontend URL
terraform output frontend_access_url

# Get the API endpoint (for frontend config)
terraform output api_gateway_url
```

## 🖥️ Using the Web Interface

1. **Open the frontend URL** from Terraform outputs
2. **Click "⚙️ API Configuration"** at the top
3. **Enter your API Gateway URL** from outputs
4. **Enter API Key** if you enabled it (optional)
5. **Start chatting!** Ask questions about your AWS costs

### Example Queries

- "What are my top 5 spending services?"
- "Show me my daily costs for the last week"
- "What's my cost forecast for next month?"
- "How can I reduce my EC2 costs?"
- "Which service costs the most?"

## 🌐 Custom Domain Setup

### Prerequisites
- Domain registered in Route53 (or external with Route53 hosted zone)
- Hosted zone already created

### Configuration Steps

1. **Find your Zone ID**:
```bash
aws route53 list-hosted-zones \
  --query 'HostedZones[*].[Name,Id]' \
  --output table
```

2. **Update terraform.tfvars**:
```hcl
domain_name      = "cost-analyzer.yourdomain.com"
route53_zone_id  = "Z1234567890ABC"  # Your zone ID
```

3. **Deploy**:
```bash
terraform apply
```

4. **Access via custom domain**:
```
http://cost-analyzer.yourdomain.com
```

### Important Notes

- **HTTP Only**: S3 static website hosting only supports HTTP
- **For HTTPS**: You would need CloudFront (not included in this simple setup)
- **DNS Propagation**: May take 5-10 minutes for Route53 changes
- **Subdomain**: Works best with subdomains (e.g., cost.example.com)

## 🔐 Security

### Production Setup

For production environments:

1. **Enable API Key**:
```hcl
enable_api_key = true
```

```bash
terraform apply
terraform output -raw api_key  # Save this securely
```

2. **Restrict S3 Bucket Access** (Optional):
For stricter security, you can add IP restrictions:

```hcl
# Add to s3-hosting.tf bucket policy
"Condition": {
  "IpAddress": {
    "aws:SourceIp": [
      "YOUR_OFFICE_IP/32",
      "YOUR_VPN_IP/32"
    ]
  }
}
```

3. **Use API Gateway Resource Policy** (Optional):
Restrict API access by IP or VPC:

```hcl
resource "aws_api_gateway_rest_api_policy" "cost_api" {
  rest_api_id = aws_api_gateway_rest_api.cost_api.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "execute-api:Invoke"
        Resource = "*"
        Condition = {
          IpAddress = {
            "aws:SourceIp": ["YOUR_IP/32"]
          }
        }
      }
    ]
  })
}
```

### CORS Configuration

CORS is automatically configured in `s3-hosting.tf` to allow:
- POST and OPTIONS methods
- Content-Type and X-Api-Key headers
- All origins (*)

For production, restrict origins in the CORS configuration.

## 💰 Cost Estimation

Monthly costs (approximate):

| Component | Usage | Cost |
|-----------|-------|------|
| S3 Hosting | 1GB storage + 10K requests | ~$0.05 |
| Lambda | 1,000 invocations | ~$0.20 |
| API Gateway | 1,000 requests | ~$3.50 |
| Cost Explorer API | 30 requests | ~$0.30 |
| Bedrock (Claude) | ~100K tokens | ~$0.30 |
| Route53 | Hosted zone + queries | ~$0.50 |
| **Total** | | **~$4.85/month** |

## 🔧 Configuration Options

### Essential Variables

```hcl
aws_region   = "us-east-1"      # AWS region
project_name = "aws-cost-agent"  # Resource prefix
environment  = "prod"            # Environment name
```

### Custom Domain

```hcl
domain_name      = "cost.example.com"  # Your domain
route53_zone_id  = "Z123ABC"           # Route53 zone ID
```

### Security Options

```hcl
enable_api_key = true  # Require API key
```

### Logging

```hcl
log_retention_days = 7  # CloudWatch logs retention
```

### Optional Features

```hcl
enable_sns_alerts    = true
alert_email          = "your-email@example.com"
enable_daily_reports = true
```

## 🔄 Updates

### Update Frontend

```bash
# Edit frontend/index.html
nano frontend/index.html

# Apply changes
terraform apply
```

### Update Lambda

```bash
# Edit lambda/lambda_function.py
nano lambda/lambda_function.py

# Apply changes
terraform apply
```

### Change Domain

```bash
# Edit terraform.tfvars
nano terraform.tfvars

# Apply changes
terraform apply
```

## 📊 Monitoring

### View Logs

```bash
# Lambda logs
aws logs tail /aws/lambda/aws-cost-agent-function --follow

# API Gateway logs
aws logs tail /aws/apigateway/aws-cost-agent --follow
```

### CloudWatch Metrics

Monitor in AWS Console:
- Lambda invocations and errors
- API Gateway requests and latency
- S3 bucket metrics
- Route53 query counts

## 🐛 Troubleshooting

### Frontend can't connect to API

1. Check API endpoint URL in frontend config
2. Verify CORS is enabled (check s3-hosting.tf)
3. Check browser console for errors
4. Verify API Gateway is deployed

```bash
# Test API directly
curl -X POST $(terraform output -raw api_gateway_url) \
  -H "Content-Type: application/json" \
  -d '{"query": "test"}'
```

### Custom domain not working

1. Wait 5-10 minutes for DNS propagation
2. Verify Route53 record was created:
```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id YOUR_ZONE_ID \
  --query "ResourceRecordSets[?Name=='your-domain.com.']"
```

3. Test DNS resolution:
```bash
nslookup cost-analyzer.yourdomain.com
```

4. Ensure S3 bucket is public:
```bash
aws s3api get-bucket-policy --bucket YOUR_BUCKET_NAME
```

### API returns 403 Forbidden

1. If API key is enabled, make sure you've entered it in frontend
2. Get API key: `terraform output -raw api_key`
3. Check IAM permissions for Lambda

### No cost data available

1. Wait 24 hours after enabling Cost Explorer
2. Verify Cost Explorer access:
```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost
```

### Bedrock access denied

1. Enable Claude model in Bedrock console
2. Verify IAM permissions include `bedrock:InvokeModel`
3. Check correct region (bedrock_region variable)

## 🧹 Cleanup

### Remove Everything

```bash
# Destroy all resources
terraform destroy

# Confirm with: yes
```

**Note**: Route53 hosted zone is NOT deleted (to prevent accidental domain issues). Delete manually if needed.

### Manual Route53 Cleanup

```bash
# List records
aws route53 list-resource-record-sets --hosted-zone-id YOUR_ZONE_ID

# Delete record (if needed)
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_ZONE_ID \
  --change-batch file://delete-record.json
```

## 📁 Project Structure

```
aws-cost-analysis-agent/
├── frontend/
│   └── index.html              # Chat interface
├── lambda/
│   └── lambda_function.py      # Cost analysis logic
├── main.tf                     # Core infrastructure
├── s3-hosting.tf               # S3 + Route53
├── variables.tf                # Configuration
├── outputs.tf                  # Deployment info
└── terraform.tfvars            # Your settings
```

## 🎯 Essential Files Only

**Required for deployment:**
1. `main.tf` - Core infrastructure
2. `s3-hosting.tf` - S3 + Route53
3. `variables.tf` - Configuration options
4. `outputs.tf` - Deployment information
5. `lambda/lambda_function.py` - Application logic
6. `frontend/index.html` - Web interface
7. `terraform.tfvars` - Your settings

**Optional:**
- `README.md` - This documentation

## 🚀 Next Steps

After deployment:

1. **Test the interface** with sample queries
2. **Enable API key** for production
3. **Configure custom domain** (optional)
4. **Set up daily reports** for insights
5. **Monitor costs** in CloudWatch
6. **Set up alerts** for anomalies

## 📚 Additional Resources

- [AWS Cost Explorer API](https://docs.aws.amazon.com/cost-management/latest/APIReference/)
- [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Route53 Documentation](https://docs.aws.amazon.com/route53/)

## ❓ Common Questions

**Q: Can I use a custom domain?**  
A: Yes, configure domain_name and route53_zone_id in terraform.tfvars

**Q: Does the custom domain support HTTPS?**  
A: No, S3 static website hosting only supports HTTP. For HTTPS, you'd need CloudFront (not included)

**Q: How do I update the frontend?**  
A: Edit `frontend/index.html` and run `terraform apply`

**Q: Can I use a domain from another registrar?**  
A: Yes, as long as you have a Route53 hosted zone for it

**Q: How do I reduce costs?**  
A: Reduce log retention, use API caching, optimize Lambda memory

## 📞 Support

For issues:
1. Check CloudWatch Logs
2. Review Terraform error messages
3. Verify all prerequisites are met
4. Test API endpoint directly
5. Check browser console for frontend errors
6. Verify DNS propagation for custom domain

---

**Deployment Time:** ~5 minutes  
**Prerequisites Setup:** 24+ hours (Cost Explorer)  
**Estimated Monthly Cost:** ~$5

🎉 **Ready to optimize your AWS costs with AI!**