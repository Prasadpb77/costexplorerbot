output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.cost_agent.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.cost_agent.arn
}

output "api_gateway_url" {
  description = "URL of the API Gateway endpoint"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/analyze"
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.cost_api.id
}

output "api_key" {
  description = "API Key for authentication (if enabled)"
  value       = var.enable_api_key ? aws_api_gateway_api_key.api_key[0].value : "API Key not enabled"
  sensitive   = true
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group for Lambda"
  value       = aws_cloudwatch_log_group.lambda_log_group.name
}

output "iam_role_arn" {
  description = "IAM Role ARN for Lambda function"
  value       = aws_iam_role.lambda_role.arn
}

output "sns_topic_arn" {
  description = "SNS Topic ARN for cost alerts (if enabled)"
  value       = var.enable_sns_alerts ? aws_sns_topic.cost_alerts[0].arn : "SNS alerts not enabled"
}

output "test_curl_command" {
  description = "Sample curl command to test the API"
  value       = <<-EOT
    curl -X POST ${aws_api_gateway_stage.prod.invoke_url}/analyze \
      -H "Content-Type: application/json" \
      ${var.enable_api_key ? "-H \"x-api-key: YOUR_API_KEY\" \\" : ""}
      -d '{"query": "What are my top spending services?"}'
  EOT
}

output "test_lambda_command" {
  description = "AWS CLI command to test Lambda directly"
  value       = <<-EOT
    aws lambda invoke \
      --function-name ${aws_lambda_function.cost_agent.function_name} \
      --payload '{"body":"{\"query\":\"What are my top spending services?\"}"}' \
      response.json && cat response.json
  EOT
}

output "view_logs_command" {
  description = "AWS CLI command to view Lambda logs"
  value       = "aws logs tail ${aws_cloudwatch_log_group.lambda_log_group.name} --follow"
}

output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "deployment_region" {
  description = "AWS Region where resources are deployed"
  value       = data.aws_region.current.name
}

output "frontend_s3_bucket" {
  description = "S3 bucket name for frontend"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_website_endpoint" {
  description = "S3 website endpoint URL"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "frontend_website_url" {
  description = "S3 website URL (HTTP)"
  value       = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "custom_domain_url" {
  description = "Custom domain URL (if configured)"
  value       = var.domain_name != "" ? "http://${var.domain_name}" : "Custom domain not configured"
}

output "frontend_access_url" {
  description = "Primary URL to access the frontend"
  value       = var.domain_name != "" ? "http://${var.domain_name}" : "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "route53_record_created" {
  description = "Whether Route53 record was created"
  value       = var.domain_name != "" ? "Yes - ${var.domain_name} points to S3" : "No - using S3 website endpoint directly"
}

output "route53_zone_id" {
  description = "Route53 Hosted Zone ID"
  value       = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : (var.route53_zone_id != "" ? var.route53_zone_id : "Not configured")
}

output "route53_name_servers" {
  description = "Route53 Name Servers (use these at your domain registrar if created new zone)"
  value       = var.create_hosted_zone ? aws_route53_zone.main[0].name_servers : []
}

output "domain_setup_instructions" {
  description = "Instructions for domain setup"
  value = var.create_hosted_zone
  }