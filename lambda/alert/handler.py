import json
import os
import boto3

s3 = boto3.client('s3')
sns = boto3.client('sns')

SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']


def lambda_handler(event, context):
    """Lambda handler triggered by S3 events in alerts/ prefix."""
    print(f"Alert Lambda triggered with event: {json.dumps(event)}")
    
    try:
        # Parse S3 event
        for record in event.get('Records', []):
            if record.get('eventName', '').startswith('ObjectCreated'):
                bucket = record['s3']['bucket']['name']
                key = record['s3']['object']['key']
                
                print(f"Processing alert for S3 object: s3://{bucket}/{key}")
                
                # Fetch earthquake data from S3
                response = s3.get_object(Bucket=bucket, Key=key)
                earthquake_data = json.loads(response['Body'].read().decode('utf-8'))
                
                # Extract earthquake details
                properties = earthquake_data.get('properties', {})
                geometry = earthquake_data.get('geometry', {})
                coordinates = geometry.get('coordinates', [])
                
                magnitude = properties.get('mag', 'Unknown')
                place = properties.get('place', 'Unknown location')
                event_time = properties.get('time', 0)
                event_url = properties.get('url', '')
                
                longitude = coordinates[0] if len(coordinates) > 0 else 'N/A'
                latitude = coordinates[1] if len(coordinates) > 1 else 'N/A'
                depth_km = coordinates[2] if len(coordinates) > 2 else 'N/A'
                
                # Format SNS message
                subject = f"🌍 Earthquake Alert: M{magnitude} - {place}"
                
                message = f"""
GROUNDSENSE EARTHQUAKE ALERT
{'=' * 50}

Magnitude: M{magnitude}
Location: {place}
Coordinates: {latitude}°N, {longitude}°E
Depth: {depth_km} km
Time: {event_time}

Details: {event_url}

{'=' * 50}
This is a Phase 1 stub. Phase 6 will integrate with 
the Bedrock Agent for intelligent alert summaries.
                """.strip()
                
                # Publish to SNS (Phase 1 stub - logs only)
                print(f"[STUB] Would publish SNS alert:")
                print(f"Subject: {subject}")
                print(f"Message: {message}")
                
                # Uncomment for actual SNS publishing:
                # sns.publish(
                #     TopicArn=SNS_TOPIC_ARN,
                #     Subject=subject,
                #     Message=message
                # )
                
                print(f"Alert processed for M{magnitude} earthquake at {place}")
    
    except Exception as e:
        print(f"Error processing alert: {e}")
        raise
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Alert processed (stub)',
            'note': 'Phase 1 stub - will integrate with Bedrock Agent in Phase 6'
        })
    }
