"""
Get Recent Earthquakes Tool

Lambda function that queries DynamoDB for recent earthquake events (last 30 days).
This tool is invoked by the Bedrock Agent when users ask about recent seismic activity.

Input Parameters:
- min_magnitude: Minimum magnitude threshold (default: 0.0)
- max_magnitude: Maximum magnitude threshold (default: 10.0)
- region: Optional geographic filter (canada, atlantic, pacific)
- limit: Maximum number of results to return (default: 50)

Output:
- List of earthquake events with timestamp, location, magnitude, depth
"""

import json
import os
from datetime import datetime, timedelta
from decimal import Decimal
import boto3
from boto3.dynamodb.conditions import Key, Attr

dynamodb = boto3.resource('dynamodb')

DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'groundsense-dev-earthquakes')
table = dynamodb.Table(DYNAMODB_TABLE_NAME)


def decimal_to_float(obj):
    """Convert Decimal objects to float for JSON serialization."""
    if isinstance(obj, list):
        return [decimal_to_float(item) for item in obj]
    elif isinstance(obj, dict):
        return {key: decimal_to_float(value) for key, value in obj.items()}
    elif isinstance(obj, Decimal):
        return float(obj)
    return obj


def filter_by_region(latitude, longitude, region):
    """Check if earthquake location matches the specified region."""
    if not region or not latitude or not longitude:
        return True
    
    region = region.lower()
    
    # Canada: Approximate bounding box
    if region == 'canada':
        return -141.0 <= longitude <= -52.0 and 41.0 <= latitude <= 83.0
    
    # Atlantic Canada: Maritime provinces + Newfoundland
    elif region == 'atlantic':
        return -67.0 <= longitude <= -52.0 and 43.0 <= latitude <= 55.0
    
    # Pacific Canada: British Columbia coast
    elif region == 'pacific':
        return -139.0 <= longitude <= -123.0 and 48.0 <= latitude <= 60.0
    
    # If unknown region, include all
    return True


def lambda_handler(event, context):
    """
    Lambda handler for Bedrock Agent tool invocation.
    
    Expected event structure from Bedrock Agent:
    {
        "actionGroup": "RecentDataQueries",
        "function": "get_recent_earthquakes",
        "parameters": [
            {"name": "min_magnitude", "value": "4.0"},
            {"name": "max_magnitude", "value": "10.0"},
            {"name": "region", "value": "canada"},
            {"name": "limit", "value": "50"}
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
    try:
        min_magnitude = float(parameters.get('min_magnitude', '0.0'))
        max_magnitude = float(parameters.get('max_magnitude', '10.0'))
        region = parameters.get('region', '').lower() if parameters.get('region') else None
        limit = int(parameters.get('limit', '50'))
    except (ValueError, TypeError) as e:
        error_msg = f"Invalid parameter format: {str(e)}"
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
                                'events': []
                            })
                        }
                    }
                }
            }
        }
    
    print(f"Query parameters: min_mag={min_magnitude}, max_mag={max_magnitude}, region={region}, limit={limit}")
    
    try:
        # Scan DynamoDB table (we don't have a GSI for magnitude range queries)
        # For production, consider adding a GSI on magnitude for better performance
        scan_params = {
            'Limit': limit * 2  # Get extra results to account for filtering
        }
        
        response = table.scan(**scan_params)
        items = response.get('Items', [])
        
        print(f"Retrieved {len(items)} items from DynamoDB")
        
        # Filter by magnitude and region
        filtered_events = []
        for item in items:
            magnitude = float(item.get('magnitude', 0))
            latitude = float(item.get('latitude', 0)) if item.get('latitude') else None
            longitude = float(item.get('longitude', 0)) if item.get('longitude') else None
            
            # Apply magnitude filter
            if not (min_magnitude <= magnitude <= max_magnitude):
                continue
            
            # Apply region filter
            if region and not filter_by_region(latitude, longitude, region):
                continue
            
            # Convert Decimal to float for JSON serialization
            event_data = {
                'earthquake_id': item.get('earthquake_id', ''),
                'magnitude': magnitude,
                'place': item.get('place', 'Unknown'),
                'time': item.get('time', ''),
                'latitude': latitude,
                'longitude': longitude,
                'depth_km': float(item.get('depth_km', 0)) if item.get('depth_km') else None,
                'source': item.get('source', ''),
                'url': item.get('url', '')
            }
            filtered_events.append(event_data)
        
        # Sort by time (most recent first) and limit results
        filtered_events.sort(key=lambda x: x.get('time', ''), reverse=True)
        filtered_events = filtered_events[:limit]
        
        print(f"Returning {len(filtered_events)} events after filtering")
        
        # Format response for Bedrock Agent
        result = {
            'query_parameters': {
                'min_magnitude': min_magnitude,
                'max_magnitude': max_magnitude,
                'region': region or 'all',
                'limit': limit
            },
            'event_count': len(filtered_events),
            'events': filtered_events
        }
        
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
        error_msg = f"Error querying DynamoDB: {str(e)}"
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
                                'events': []
                            })
                        }
                    }
                }
            }
        }
