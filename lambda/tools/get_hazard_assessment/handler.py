"""
Get Hazard Assessment Tool

Lambda function that retrieves relevant context from Bedrock Knowledge Base (RAG over PDFs).
This tool is invoked by the Bedrock Agent when users ask about seismic hazard assessments,
historical reports, or narrative context from documents.

Input Parameters:
- query: Natural language question or search query
- max_results: Maximum number of chunks to return (default: 5)

Output:
- List of text chunks with relevance scores and source citations (PDF names, pages)
"""

import json
import os
import boto3

bedrock_agent_runtime = boto3.client('bedrock-agent-runtime')

KNOWLEDGE_BASE_ID = os.environ.get('KNOWLEDGE_BASE_ID', 'GMWMMJW0TE')


def lambda_handler(event, context):
    """
    Lambda handler for Bedrock Agent tool invocation.
    
    Expected event structure from Bedrock Agent:
    {
        "actionGroup": "KnowledgeBaseRetrieval",
        "function": "get_hazard_assessment",
        "parameters": [
            {"name": "query", "value": "What does the report say about Halifax seismic risk?"},
            {"name": "max_results", "value": "5"}
        ]
    }
    """
    print(f"Received event: {json.dumps(event)}")
    
    # Parse parameters from Bedrock Agent format
    parameters = {}
    for param in event.get('parameters', []):
        param_name = param.get('name')
        param_value = param.get('value')
        if param_name and param_value:
            parameters[param_name] = param_value
    
    # Extract and validate parameters
    query = parameters.get('query', '').strip()
    
    if not query:
        error_msg = "Query parameter is required"
        print(f"ERROR: {error_msg}")
        return {
            'response': {
                'actionGroup': event.get('actionGroup'),
                'function': event.get('function'),
                'functionResponse': {
                    'responseBody': {
                        'TEXT': {
                            'body': json.dumps({
                                'error': error_msg,
                                'results': []
                            })
                        }
                    }
                }
            }
        }
    
    try:
        max_results = int(parameters.get('max_results', '5'))
    except (ValueError, TypeError):
        max_results = 5
    
    print(f"Query: '{query}' (max_results={max_results})")
    
    try:
        # Retrieve from Bedrock Knowledge Base
        response = bedrock_agent_runtime.retrieve(
            knowledgeBaseId=KNOWLEDGE_BASE_ID,
            retrievalQuery={
                'text': query
            },
            retrievalConfiguration={
                'vectorSearchConfiguration': {
                    'numberOfResults': max_results
                }
            }
        )
        
        # Parse retrieval results
        retrieval_results = response.get('retrievalResults', [])
        print(f"Retrieved {len(retrieval_results)} chunks from Knowledge Base")
        
        # Format results
        formatted_results = []
        for i, result in enumerate(retrieval_results):
            content = result.get('content', {}).get('text', '')
            score = result.get('score', 0.0)
            location = result.get('location', {})
            
            # Extract source information
            s3_location = location.get('s3Location', {})
            uri = s3_location.get('uri', '')
            
            # Parse S3 URI to get filename
            filename = ''
            if uri:
                # URI format: s3://bucket-name/path/to/file.pdf
                parts = uri.split('/')
                if len(parts) > 0:
                    filename = parts[-1]
            
            formatted_result = {
                'rank': i + 1,
                'content': content,
                'relevance_score': round(score, 4),
                'source': {
                    'document': filename,
                    's3_uri': uri
                }
            }
            
            formatted_results.append(formatted_result)
        
        # Build response
        result = {
            'query': query,
            'result_count': len(formatted_results),
            'results': formatted_results
        }
        
        print(f"Returning {len(formatted_results)} results")
        
        return {
            'response': {
                'actionGroup': event.get('actionGroup'),
                'function': event.get('function'),
                'functionResponse': {
                    'responseBody': {
                        'TEXT': {
                            'body': json.dumps(result)
                        }
                    }
                }
            }
        }
        
    except Exception as e:
        error_msg = f"Error retrieving from Knowledge Base: {str(e)}"
        print(f"ERROR: {error_msg}")
        import traceback
        traceback.print_exc()
        
        return {
            'response': {
                'actionGroup': event.get('actionGroup'),
                'function': event.get('function'),
                'functionResponse': {
                    'responseBody': {
                        'TEXT': {
                            'body': json.dumps({
                                'error': error_msg,
                                'results': []
                            })
                        }
                    }
                }
            }
        }
