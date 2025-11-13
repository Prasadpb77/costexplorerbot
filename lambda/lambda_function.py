import json
import os
import boto3
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

# Initialize AWS clients
ce_client = boto3.client('ce')
bedrock_region = os.environ.get('BEDROCK_REGION', 'us-east-1')
bedrock_runtime = boto3.client('bedrock-runtime', region_name=bedrock_region)
MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'amazon.nova-premier-v1:0')

def get_cost_and_usage(start_date, end_date, granularity='DAILY', metrics=['UnblendedCost'], group_by=None):
    """Fetch cost and usage data from AWS Cost Explorer"""
    try:
        params = {
            'TimePeriod': {
                'Start': start_date,
                'End': end_date
            },
            'Granularity': granularity,
            'Metrics': metrics
        }
        
        if group_by:
            params['GroupBy'] = group_by
        
        response = ce_client.get_cost_and_usage(**params)
        return response
    except ClientError as e:
        print(f"Error fetching cost data: {e}")
        return None

def get_service_costs(days=30):
    """Get costs grouped by service"""
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=days)
    
    return get_cost_and_usage(
        start_date=start_date.strftime('%Y-%m-%d'),
        end_date=end_date.strftime('%Y-%m-%d'),
        granularity='MONTHLY',
        metrics=['UnblendedCost'],
        group_by=[{'Type': 'DIMENSION', 'Key': 'SERVICE'}]
    )

def get_daily_costs(days=7):
    """Get daily cost breakdown"""
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=days)
    
    return get_cost_and_usage(
        start_date=start_date.strftime('%Y-%m-%d'),
        end_date=end_date.strftime('%Y-%m-%d'),
        granularity='DAILY',
        metrics=['UnblendedCost']
    )

def get_cost_forecast(days=30):
    """Get cost forecast"""
    try:
        start_date = datetime.now().date()
        end_date = start_date + timedelta(days=days)
        
        response = ce_client.get_cost_forecast(
            TimePeriod={
                'Start': start_date.strftime('%Y-%m-%d'),
                'End': end_date.strftime('%Y-%m-%d')
            },
            Metric='UNBLENDED_COST',
            Granularity='MONTHLY'
        )
        return response
    except ClientError as e:
        print(f"Error fetching forecast: {e}")
        return None

def format_cost_data(cost_data, data_type='service'):
    """Format cost data into a readable string"""
    if not cost_data or 'ResultsByTime' not in cost_data:
        return "No cost data available"
    
    formatted_output = []
    
    for result in cost_data['ResultsByTime']:
        time_period = f"{result['TimePeriod']['Start']} to {result['TimePeriod']['End']}"
        formatted_output.append(f"\n=== Period: {time_period} ===")
        
        if 'Groups' in result:
            for group in result['Groups']:
                service = group['Keys'][0]
                amount = float(group['Metrics']['UnblendedCost']['Amount'])
                if amount > 0.01:
                    formatted_output.append(f"  {service}: ${amount:.2f}")
        else:
            total = float(result['Total']['UnblendedCost']['Amount'])
            formatted_output.append(f"  Total: ${total:.2f}")
    
    return "\n".join(formatted_output)

def query_bedrock(user_query, cost_context):
    """Send query to Bedrock with cost context"""
    system_prompt = """You are an AWS cost analysis assistant. You have access to the AWS account's cost and usage data. 
    Your job is to help users understand their AWS spending, identify cost trends, and provide recommendations for cost optimization.
    Always provide specific numbers from the data when available and give actionable insights."""
    
    user_message = f"""Here is the AWS cost data:

{cost_context}

User Question: {user_query}

Please analyze this data and answer the user's question with specific insights and recommendations."""

    try:
        request_body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2000,
            "temperature": 0.7,
            "system": system_prompt,
            "messages": [
                {
                    "role": "user",
                    "content": user_message
                }
            ]
        }
        
        response = bedrock_runtime.invoke_model(
            modelId=MODEL_ID,
            body=json.dumps(request_body)
        )
        
        response_body = json.loads(response['body'].read())
        return response_body['content'][0]['text']
        
    except ClientError as e:
        print(f"Error calling Bedrock: {e}")
        return "Sorry, I couldn't process your request at this time."

def process_user_query(user_query):
    """Main method to process user queries"""
    query_lower = user_query.lower()
    
    # Gather relevant cost data based on query
    cost_context = ""
    
    if any(word in query_lower for word in ['service', 'services', 'which', 'what', 'top', 'spending']):
        service_costs = get_service_costs(days=30)
        if service_costs:
            cost_context += "\n\n=== SERVICE COSTS (Last 30 Days) ===\n"
            cost_context += format_cost_data(service_costs, 'service')
    
    if any(word in query_lower for word in ['daily', 'day', 'week', 'trend', 'yesterday']):
        daily_costs = get_daily_costs(days=7)
        if daily_costs:
            cost_context += "\n\n=== DAILY COSTS (Last 7 Days) ===\n"
            cost_context += format_cost_data(daily_costs, 'daily')
    
    if any(word in query_lower for word in ['forecast', 'predict', 'future', 'next month', 'projection']):
        forecast = get_cost_forecast(days=30)
        if forecast:
            cost_context += "\n\n=== COST FORECAST (Next 30 Days) ===\n"
            total_forecast = float(forecast['Total']['Amount'])
            cost_context += f"Predicted cost: ${total_forecast:.2f}"
    
    # If no specific keywords, get general overview
    if not cost_context:
        service_costs = get_service_costs(days=30)
        daily_costs = get_daily_costs(days=7)
        if service_costs:
            cost_context += "\n\n=== SERVICE COSTS (Last 30 Days) ===\n"
            cost_context += format_cost_data(service_costs, 'service')
        if daily_costs:
            cost_context += "\n\n=== DAILY COSTS (Last 7 Days) ===\n"
            cost_context += format_cost_data(daily_costs, 'daily')
    
    # If still no context, return error message
    if not cost_context or cost_context.strip() == "":
        return "Unable to retrieve cost data. Please ensure Cost Explorer is enabled and has collected data for at least 24 hours."
    
    # Query Bedrock with the cost context
    response = query_bedrock(user_query, cost_context)
    return response

def lambda_handler(event, context):
    """AWS Lambda handler function"""
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Handle different event sources (API Gateway, EventBridge, direct invocation)
        if 'body' in event:
            # API Gateway or direct invocation with body
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
        else:
            # EventBridge or other sources
            body = event
        
        user_query = body.get('query', '')
        
        if not user_query:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'No query provided. Please include a "query" field in the request body.'
                })
            }
        
        print(f"Processing query: {user_query}")
        
        # Process the query
        response_text = process_user_query(user_query)
        
        result = {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'query': user_query,
                'response': response_text,
                'timestamp': datetime.now().isoformat(),
                'model': MODEL_ID
            })
        }
        
        print(f"Returning response: {result['statusCode']}")
        return result
        
    except Exception as e:
        print(f"Error in lambda_handler: {str(e)}")
        import traceback
        traceback.print_exc()
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': str(e),
                'message': 'Internal server error occurred while processing your request.'
            })
        }