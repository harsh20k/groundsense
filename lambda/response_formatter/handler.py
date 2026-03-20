"""
Response Formatter Lambda

This Lambda wraps the Bedrock Agent and structures its output for frontend consumption.
It captures agent traces to extract tool calls and map them to visualization types.

Input (from API Gateway or direct invocation):
{
    "query": "Show me recent earthquakes above M4.0",
    "session_id": "optional-session-id"
}

Output:
{
    "message": "Agent's natural language response",
    "session_id": "abc123",
    "visualization": {
        "type": "earthquake_map | line_chart | stat_card | ...",
        "title": "Recent Earthquakes (9 events)",
        "data": [...]
    }
}
"""

import json
import os
import boto3
from datetime import datetime

bedrock_agent_runtime = boto3.client('bedrock-agent-runtime')

AGENT_ID = os.environ.get('AGENT_ID')
AGENT_ALIAS_ID = os.environ.get('AGENT_ALIAS_ID')


def _parse_request_body(event):
    """
    Normalize payload from:
    - Direct invoke: {"query": "...", "session_id": "..."}
    - Lambda Function URL / API Gateway: {"body": "{\"query\":...}", ...}
    """
    if not isinstance(event, dict):
        return {}
    raw_body = event.get('body')
    if raw_body is not None:
        if isinstance(raw_body, str):
            if not raw_body.strip():
                return {}
            try:
                return json.loads(raw_body)
            except json.JSONDecodeError:
                return {}
        if isinstance(raw_body, dict):
            return raw_body
    return event


def lambda_handler(event, context):
    """Main Lambda handler."""
    print(f"Received event: {json.dumps(event)}")
    
    body = _parse_request_body(event)
    query = body.get('query', '').strip()
    session_id = body.get('session_id', f"session-{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}")
    
    if not query:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Query parameter is required'})
        }
    
    if not AGENT_ID or not AGENT_ALIAS_ID:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Agent configuration missing'})
        }
    
    try:
        # Invoke agent with trace enabled
        response = bedrock_agent_runtime.invoke_agent(
            agentId=AGENT_ID,
            agentAliasId=AGENT_ALIAS_ID,
            sessionId=session_id,
            inputText=query,
            enableTrace=True
        )
        
        # Process event stream
        event_stream = response['completion']
        message_chunks = []
        tool_calls = []
        current_invocation = None
        
        for event in event_stream:
            # Collect text chunks
            if 'chunk' in event:
                chunk = event['chunk']
                if 'bytes' in chunk:
                    text = chunk['bytes'].decode('utf-8')
                    message_chunks.append(text)
            
            # Parse trace events for tool calls
            elif 'trace' in event:
                trace = event['trace'].get('trace', {})
                orch = trace.get('orchestrationTrace', {})
                
                # Capture tool invocation input
                if 'invocationInput' in orch:
                    inv_input = orch['invocationInput']
                    action_group_input = inv_input.get('actionGroupInvocationInput', {})
                    
                    if action_group_input:
                        function_name = action_group_input.get('function', '')
                        parameters = action_group_input.get('parameters', [])
                        
                        # Parse parameters into dict
                        param_dict = {}
                        for param in parameters:
                            param_dict[param.get('name')] = param.get('value')
                        
                        current_invocation = {
                            'function': function_name,
                            'parameters': param_dict,
                            'output': None
                        }
                
                # Capture tool invocation output
                elif 'observation' in orch and current_invocation:
                    observation = orch['observation']
                    action_group_output = observation.get('actionGroupInvocationOutput', {})
                    
                    if action_group_output:
                        text_output = action_group_output.get('text', '')
                        try:
                            # Parse JSON response from tool
                            current_invocation['output'] = json.loads(text_output)
                            tool_calls.append(current_invocation)
                            current_invocation = None
                        except json.JSONDecodeError:
                            print(f"Warning: Could not parse tool output as JSON: {text_output[:100]}")
        
        # Combine message
        message = ''.join(message_chunks)
        
        # Build visualization from tool calls
        visualization = build_visualization(tool_calls)
        
        # Format final response
        result = {
            'message': message,
            'session_id': session_id,
            'visualization': visualization
        }
        
        print(f"Response: {len(message)} chars, visualization type: {visualization['type']}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(result)
        }
        
    except Exception as e:
        error_msg = f"Error invoking agent: {str(e)}"
        print(f"ERROR: {error_msg}")
        import traceback
        traceback.print_exc()
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': error_msg,
                'message': '',
                'visualization': {'type': 'none'}
            })
        }


def build_visualization(tool_calls):
    """
    Map tool calls to visualization payload.
    
    Priority order (first match wins):
    1. get_recent_earthquakes → earthquake_map
    2. analyze_historical_patterns → line_chart | stat_card
    3. get_location_context → location_map
    4. fetch_weather_at_epicenter → weather_card
    5. get_hazard_assessment → document_excerpt
    """
    if not tool_calls:
        return {'type': 'none'}
    
    # Priority 1: Recent earthquakes map
    for call in tool_calls:
        if call['function'] == 'get_recent_earthquakes' and call['output']:
            output = call['output']
            events = output.get('events', [])
            
            if events:
                # Map to earthquake_map format
                map_data = []
                for evt in events:
                    map_data.append({
                        'latitude': evt.get('latitude'),
                        'longitude': evt.get('longitude'),
                        'magnitude': evt.get('magnitude'),
                        'place': evt.get('place'),
                        'time': evt.get('time'),
                        'depth_km': evt.get('depth_km'),
                        'earthquake_id': evt.get('earthquake_id')
                    })
                
                return {
                    'type': 'earthquake_map',
                    'title': f"Recent Earthquakes ({len(events)} events)",
                    'data': map_data
                }
    
    # Priority 2: Historical patterns (analyze_historical_patterns)
    for call in tool_calls:
        if call['function'] == 'analyze_historical_patterns' and call['output']:
            output = call['output']
            query_params = output.get('query_parameters', {})
            query_type = query_params.get('query_type', 'count')
            results = output.get('results', {})
            data = results.get('data', [])
            
            # Timeseries → line_chart
            if query_type == 'timeseries' and data:
                return {
                    'type': 'line_chart',
                    'title': 'Earthquake Trends Over Time',
                    'data': data
                }
            
            # Max → earthquake_map (top historical events)
            elif query_type == 'max' and data:
                map_data = []
                for evt in data:
                    if evt.get('latitude') and evt.get('longitude'):
                        map_data.append({
                            'latitude': evt.get('latitude'),
                            'longitude': evt.get('longitude'),
                            'magnitude': evt.get('magnitude'),
                            'place': evt.get('place'),
                            'time': evt.get('time'),
                            'depth_km': evt.get('depth_km'),
                            'earthquake_id': evt.get('earthquake_id', '')
                        })
                
                if map_data:
                    return {
                        'type': 'earthquake_map',
                        'title': f"Top {len(map_data)} Historical Events",
                        'data': map_data
                    }
            
            # Count or average → stat_card
            elif query_type in ['count', 'average'] and data:
                stats = data[0] if data else {}
                return {
                    'type': 'stat_card',
                    'title': 'Historical Statistics',
                    'data': stats
                }
    
    # Priority 3: Location context (standalone)
    # Tool schema: display_name, coordinates{}, population_centers, tectonic_context (KB chunk list)
    for call in tool_calls:
        if call['function'] == 'get_location_context' and call['output']:
            output = call['output']
            
            coords = output.get('coordinates') or {}
            lat = output.get('latitude') or coords.get('latitude')
            lon = output.get('longitude') or coords.get('longitude')
            
            if lat and lon:
                label = (
                    output.get('display_name')
                    or output.get('query')
                    or output.get('nearest_city')
                    or 'Location Context'
                )
                excerpts = output.get('tectonic_context') or []
                # Normalize KB rows for UI (tool uses flat "source" string)
                context_excerpts = []
                for row in excerpts:
                    if isinstance(row, dict) and row.get('content'):
                        context_excerpts.append({
                            'content': row.get('content', ''),
                            'relevance_score': row.get('relevance_score'),
                            'source': row.get('source', ''),
                        })
                return {
                    'type': 'location_map',
                    'title': label[:120] if isinstance(label, str) else 'Location Context',
                    'data': {
                        'latitude': lat,
                        'longitude': lon,
                        'name': output.get('display_name') or output.get('query', ''),
                        'nearest_city': output.get('nearest_city', ''),
                        'nearby_cities': output.get('population_centers', []),
                        'context_excerpts': context_excerpts,
                    }
                }
    
    # Priority 4: Weather (standalone)
    for call in tool_calls:
        if call['function'] == 'fetch_weather_at_epicenter' and call['output']:
            output = call['output']
            
            return {
                'type': 'weather_card',
                'title': 'Weather at Epicenter',
                'data': {
                    'temperature': output.get('temperature_c'),
                    'wind_speed': output.get('wind_speed_kmh'),
                    'precipitation': output.get('precipitation_mm'),
                    'description': output.get('weather_description', ''),
                    'noise_risk': output.get('seismic_noise_risk', 'unknown'),
                    'latitude': output.get('latitude'),
                    'longitude': output.get('longitude')
                }
            }
    
    # Priority 5: Document excerpts
    for call in tool_calls:
        if call['function'] == 'get_hazard_assessment' and call['output']:
            output = call['output']
            results = output.get('results', [])
            
            if results:
                doc_data = []
                for result in results:
                    doc_data.append({
                        'content': result.get('content', ''),
                        'source': result.get('source', {}).get('document', ''),
                        'score': result.get('relevance_score', 0.0)
                    })
                
                return {
                    'type': 'document_excerpt',
                    'title': 'Document Excerpts',
                    'data': doc_data
                }
    
    # No visualizable data
    return {'type': 'none'}
