import json
import os
import boto3

s3 = boto3.client('s3')
bedrock_agent = boto3.client('bedrock-agent')


def lambda_handler(event, context):
    """Lambda handler triggered by S3 events in documents bucket."""
    print(f"KB Sync Lambda triggered with event: {json.dumps(event)}")
    
    # Get KB and Data Source IDs from environment variables
    knowledge_base_id = os.environ.get('KNOWLEDGE_BASE_ID', '')
    data_source_id = os.environ.get('DATA_SOURCE_ID', '')
    
    if not knowledge_base_id or not data_source_id:
        print("WARNING: KNOWLEDGE_BASE_ID or DATA_SOURCE_ID not configured")
        print("This Lambda needs to be configured with Phase 2 outputs")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'KB sync skipped - not configured',
                'note': 'Run Phase 2 deployment and add KB/DS IDs to terraform.tfvars'
            })
        }
    
    try:
        # Parse S3 event
        for record in event.get('Records', []):
            if record.get('eventName', '').startswith('ObjectCreated'):
                bucket = record['s3']['bucket']['name']
                key = record['s3']['object']['key']
                size = record['s3']['object'].get('size', 0)
                
                print(f"Processing new document: s3://{bucket}/{key}")
                print(f"Document size: {size} bytes")
                
                # Start ingestion job (processes all documents in data source)
                print(f"Starting ingestion job for Knowledge Base: {knowledge_base_id}")
                response = bedrock_agent.start_ingestion_job(
                    knowledgeBaseId=knowledge_base_id,
                    dataSourceId=data_source_id
                )
                
                ingestion_job_id = response['ingestionJob']['ingestionJobId']
                status = response['ingestionJob']['status']
                
                print(f"✓ Started ingestion job: {ingestion_job_id}")
                print(f"  Status: {status}")
                print(f"  Note: This job will sync ALL documents in the data source")
                
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': 'KB sync initiated successfully',
                        'ingestion_job_id': ingestion_job_id,
                        'status': status,
                        'document': f"s3://{bucket}/{key}"
                    })
                }
    
    except Exception as e:
        print(f"Error processing KB sync: {e}")
        raise
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'KB sync completed',
            'note': 'No new documents to process'
        })
    }
