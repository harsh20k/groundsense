"""
Analyze Historical Patterns Tool

Lambda function that runs Athena SQL queries on the S3 data lake for long-term seismic trends.
This tool is invoked by the Bedrock Agent when users ask about historical earthquake patterns.

Input Parameters:
- query_type: Type of analysis (count, average, max, timeseries)
- time_range_days: Number of days to analyze (default: 365)
- min_magnitude: Minimum magnitude threshold (default: 0.0)
- region: Optional geographic filter (canada, atlantic, pacific)

Output:
- Aggregated statistics or time-series data based on query_type
"""

import json
import os
import time
from datetime import datetime, timedelta
import boto3

athena = boto3.client('athena')
s3 = boto3.client('s3')

ATHENA_WORKGROUP = os.environ.get('ATHENA_WORKGROUP_NAME', 'groundsense-dev-seismic-analysis')
GLUE_DATABASE = os.environ.get('GLUE_DATABASE_NAME', 'groundsense_dev_seismic_data')
S3_OUTPUT_BUCKET = os.environ.get('S3_ATHENA_OUTPUT_BUCKET', 'groundsense-dev-seismic-archive')
ATHENA_OUTPUT_LOCATION = f's3://{S3_OUTPUT_BUCKET}/athena-results/'


def build_region_filter(region):
    """Build SQL WHERE clause for region filtering."""
    if not region:
        return ""
    
    region = region.lower()
    
    if region == 'canada':
        return "AND longitude BETWEEN -141.0 AND -52.0 AND latitude BETWEEN 41.0 AND 83.0"
    elif region == 'atlantic':
        return "AND longitude BETWEEN -67.0 AND -52.0 AND latitude BETWEEN 43.0 AND 55.0"
    elif region == 'pacific':
        return "AND longitude BETWEEN -139.0 AND -123.0 AND latitude BETWEEN 48.0 AND 60.0"
    
    return ""


def generate_sql_query(query_type, time_range_days, min_magnitude, region):
    """Generate Athena SQL query based on parameters."""
    
    # Calculate date range
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=time_range_days)
    
    # Format dates for Athena (YYYY-MM-DD)
    start_date_str = start_date.strftime('%Y-%m-%d')
    end_date_str = end_date.strftime('%Y-%m-%d')
    
    region_filter = build_region_filter(region)
    
    # Build SQL based on query type
    if query_type == 'count':
        sql = f"""
        SELECT COUNT(*) as earthquake_count
        FROM earthquakes
        WHERE year >= '{start_date.year}'
          AND TRY_CAST(magnitude AS DOUBLE) >= {min_magnitude}
          AND TRY(date_parse(time, '%Y-%m-%dT%H:%i:%s')) >= date_parse('{start_date_str}', '%Y-%m-%d')
          AND TRY(date_parse(time, '%Y-%m-%dT%H:%i:%s')) <= date_parse('{end_date_str}', '%Y-%m-%d')
          {region_filter}
        """
    
    elif query_type == 'average':
        sql = f"""
        SELECT 
            AVG(TRY_CAST(magnitude AS DOUBLE)) as avg_magnitude,
            MIN(TRY_CAST(magnitude AS DOUBLE)) as min_magnitude,
            MAX(TRY_CAST(magnitude AS DOUBLE)) as max_magnitude,
            COUNT(*) as event_count
        FROM earthquakes
        WHERE year >= '{start_date.year}'
          AND TRY_CAST(magnitude AS DOUBLE) >= {min_magnitude}
          AND TRY(date_parse(time, '%Y-%m-%dT%H:%i:%s')) >= date_parse('{start_date_str}', '%Y-%m-%d')
          AND TRY(date_parse(time, '%Y-%m-%dT%H:%i:%s')) <= date_parse('{end_date_str}', '%Y-%m-%d')
          {region_filter}
        """
    
    elif query_type == 'max':
        sql = f"""
        SELECT 
            earthquake_id,
            TRY_CAST(magnitude AS DOUBLE) as magnitude,
            place,
            time,
            TRY_CAST(latitude AS DOUBLE) as latitude,
            TRY_CAST(longitude AS DOUBLE) as longitude,
            TRY_CAST(depth_km AS DOUBLE) as depth_km,
            source
        FROM earthquakes
        WHERE year >= '{start_date.year}'
          AND TRY_CAST(magnitude AS DOUBLE) >= {min_magnitude}
          AND TRY(date_parse(time, '%Y-%m-%dT%H:%i:%s')) >= date_parse('{start_date_str}', '%Y-%m-%d')
          AND TRY(date_parse(time, '%Y-%m-%dT%H:%i:%s')) <= date_parse('{end_date_str}', '%Y-%m-%d')
          {region_filter}
        ORDER BY TRY_CAST(magnitude AS DOUBLE) DESC
        LIMIT 10
        """
    
    elif query_type == 'timeseries':
        sql = f"""
        SELECT 
            substr(time, 1, 7) as month,
            COUNT(*) as event_count,
            AVG(TRY_CAST(magnitude AS DOUBLE)) as avg_magnitude,
            MAX(TRY_CAST(magnitude AS DOUBLE)) as max_magnitude
        FROM earthquakes
        WHERE year >= '{start_date.year}'
          AND TRY_CAST(magnitude AS DOUBLE) >= {min_magnitude}
          AND TRY(date_parse(time, '%Y-%m-%dT%H:%i:%s')) >= date_parse('{start_date_str}', '%Y-%m-%d')
          AND TRY(date_parse(time, '%Y-%m-%dT%H:%i:%s')) <= date_parse('{end_date_str}', '%Y-%m-%d')
          {region_filter}
        GROUP BY substr(time, 1, 7)
        ORDER BY month DESC
        LIMIT 24
        """
    
    else:
        raise ValueError(f"Unknown query_type: {query_type}")
    
    return sql.strip()


def execute_athena_query(sql_query):
    """Execute Athena query and wait for results (with timeout)."""
    
    print(f"Executing Athena query:\n{sql_query}")
    
    try:
        # Start query execution
        response = athena.start_query_execution(
            QueryString=sql_query,
            QueryExecutionContext={'Database': GLUE_DATABASE},
            ResultConfiguration={'OutputLocation': ATHENA_OUTPUT_LOCATION},
            WorkGroup=ATHENA_WORKGROUP
        )
        
        query_execution_id = response['QueryExecutionId']
        print(f"Query execution started: {query_execution_id}")
        
        # Poll for completion (max 10 seconds)
        max_wait = 10
        poll_interval = 1
        elapsed = 0
        
        while elapsed < max_wait:
            status_response = athena.get_query_execution(QueryExecutionId=query_execution_id)
            status = status_response['QueryExecution']['Status']['State']
            
            if status == 'SUCCEEDED':
                print(f"Query succeeded after {elapsed}s")
                break
            elif status in ['FAILED', 'CANCELLED']:
                reason = status_response['QueryExecution']['Status'].get('StateChangeReason', 'Unknown')
                raise Exception(f"Query {status}: {reason}")
            
            time.sleep(poll_interval)
            elapsed += poll_interval
        
        if elapsed >= max_wait:
            print(f"Query timeout after {max_wait}s - returning partial results")
            return {
                'timeout': True,
                'query_execution_id': query_execution_id,
                'message': 'Query is still running. Try a shorter time range or simpler query.'
            }
        
        # Get query results
        results_response = athena.get_query_results(QueryExecutionId=query_execution_id)
        
        # Parse results
        rows = results_response['ResultSet']['Rows']
        if len(rows) <= 1:
            return {'data': [], 'row_count': 0}
        
        # Extract column names from first row
        column_info = rows[0]['Data']
        columns = [col.get('VarCharValue', '') for col in column_info]
        
        # Extract data rows
        data = []
        for row in rows[1:]:
            row_data = {}
            for i, cell in enumerate(row['Data']):
                value = cell.get('VarCharValue')
                if value and columns[i]:
                    # Try to convert to number if possible
                    try:
                        if '.' in value:
                            row_data[columns[i]] = float(value)
                        else:
                            row_data[columns[i]] = int(value)
                    except ValueError:
                        row_data[columns[i]] = value
            data.append(row_data)
        
        return {
            'data': data,
            'row_count': len(data),
            'query_execution_id': query_execution_id
        }
        
    except Exception as e:
        print(f"Error executing Athena query: {str(e)}")
        raise


def lambda_handler(event, context):
    """
    Lambda handler for Bedrock Agent tool invocation.
    
    Expected event structure from Bedrock Agent:
    {
        "actionGroup": "HistoricalAnalytics",
        "function": "analyze_historical_patterns",
        "parameters": [
            {"name": "query_type", "value": "count"},
            {"name": "time_range_days", "value": "365"},
            {"name": "min_magnitude", "value": "0.0"},
            {"name": "region", "value": "canada"}
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
        query_type = parameters.get('query_type', 'count').lower()
        time_range_days = int(parameters.get('time_range_days', '365'))
        min_magnitude = float(parameters.get('min_magnitude', '0.0'))
        region = parameters.get('region', '').lower() if parameters.get('region') else None
        
        # Validate query_type
        valid_types = ['count', 'average', 'max', 'timeseries']
        if query_type not in valid_types:
            raise ValueError(f"query_type must be one of: {', '.join(valid_types)}")
        
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
                                'data': []
                            })
                        }
                    }
                }
            }
        }
    
    print(f"Query parameters: type={query_type}, days={time_range_days}, min_mag={min_magnitude}, region={region}")
    
    try:
        # Generate and execute SQL query
        sql_query = generate_sql_query(query_type, time_range_days, min_magnitude, region)
        query_results = execute_athena_query(sql_query)
        
        # Format response
        result = {
            'query_parameters': {
                'query_type': query_type,
                'time_range_days': time_range_days,
                'min_magnitude': min_magnitude,
                'region': region or 'all'
            },
            'results': query_results
        }
        
        print(f"Returning {query_results.get('row_count', 0)} rows")
        
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
        error_msg = f"Error analyzing historical patterns: {str(e)}"
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
                                'data': []
                            })
                        }
                    }
                }
            }
        }
