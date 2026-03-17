import json
import os
from datetime import datetime, timedelta
from decimal import Decimal
import urllib.request
import urllib.error
import boto3

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')

DYNAMODB_TABLE_NAME = os.environ['DYNAMODB_TABLE_NAME']
S3_BUCKET_NAME = os.environ['S3_BUCKET_NAME']
TTL_DAYS = int(os.environ.get('TTL_DAYS', '30'))

table = dynamodb.Table(DYNAMODB_TABLE_NAME)


def fetch_nrcan_data():
    """Fetch recent earthquake data from NRCan FDSN API."""
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(hours=1)
    
    url = (
        f"https://earthquakescanada.nrcan.gc.ca/fdsnws/event/1/query?"
        f"format=geojson&"
        f"starttime={start_time.isoformat()}&"
        f"endtime={end_time.isoformat()}&"
        f"minmagnitude=0.0"
    )
    
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            data = json.loads(response.read().decode())
            print(f"Fetched {len(data.get('features', []))} events from NRCan")
            return data.get('features', [])
    except urllib.error.URLError as e:
        print(f"Error fetching NRCan data: {e}")
        return []


def fetch_usgs_data():
    """Fetch recent earthquake data from USGS real-time feed."""
    url = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson"
    
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            data = json.loads(response.read().decode())
            print(f"Fetched {len(data.get('features', []))} events from USGS")
            return data.get('features', [])
    except urllib.error.URLError as e:
        print(f"Error fetching USGS data: {e}")
        return []


def convert_floats_to_decimal(obj):
    """Convert float values to Decimal for DynamoDB compatibility."""
    if isinstance(obj, list):
        return [convert_floats_to_decimal(item) for item in obj]
    elif isinstance(obj, dict):
        return {key: convert_floats_to_decimal(value) for key, value in obj.items()}
    elif isinstance(obj, float):
        return Decimal(str(obj))
    return obj


def process_event(feature, source):
    """Process a single earthquake event and store it."""
    try:
        properties = feature.get('properties', {})
        geometry = feature.get('geometry', {})
        coordinates = geometry.get('coordinates', [])
        
        # Extract earthquake details
        event_id = feature.get('id', '')
        magnitude = properties.get('mag')
        place = properties.get('place', 'Unknown')
        time_ms = properties.get('time', 0)
        event_time = datetime.utcfromtimestamp(time_ms / 1000).isoformat() if time_ms else None
        
        longitude = coordinates[0] if len(coordinates) > 0 else None
        latitude = coordinates[1] if len(coordinates) > 1 else None
        depth_km = coordinates[2] if len(coordinates) > 2 else None
        
        if not event_id or magnitude is None:
            print(f"Skipping event with missing required fields: {event_id}")
            return
        
        # Prepare DynamoDB item
        ttl_timestamp = int((datetime.utcnow() + timedelta(days=TTL_DAYS)).timestamp())
        
        item = {
            'earthquake_id': event_id,
            'magnitude': magnitude,
            'place': place,
            'time': event_time,
            'longitude': longitude,
            'latitude': latitude,
            'depth_km': depth_km,
            'source': source,
            'url': properties.get('url', ''),
            'type': properties.get('type', ''),
            'expires_at': ttl_timestamp,
            'created_at': datetime.utcnow().isoformat()
        }
        
        # Convert floats to Decimal for DynamoDB
        item = convert_floats_to_decimal(item)
        
        # Write to DynamoDB (conditional to avoid duplicates)
        try:
            table.put_item(
                Item=item,
                ConditionExpression='attribute_not_exists(earthquake_id)'
            )
            print(f"Stored event {event_id} (M{magnitude}) in DynamoDB")
        except dynamodb.meta.client.exceptions.ConditionalCheckFailedException:
            print(f"Event {event_id} already exists in DynamoDB, skipping")
            return
        
        # Write to S3
        now = datetime.utcnow()
        s3_key_data = f"data/{now.year}/{now.month:02d}/{now.day:02d}/{event_id}.json"
        
        s3.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=s3_key_data,
            Body=json.dumps(feature, default=str),
            ContentType='application/json'
        )
        print(f"Stored event {event_id} in S3 at {s3_key_data}")
        
        # If M5.0+, also write to alerts/ prefix for alert Lambda trigger
        if magnitude >= 5.0:
            s3_key_alert = f"alerts/{now.year}/{now.month:02d}/{now.day:02d}/{event_id}.json"
            s3.put_object(
                Bucket=S3_BUCKET_NAME,
                Key=s3_key_alert,
                Body=json.dumps(feature, default=str),
                ContentType='application/json'
            )
            print(f"Stored M{magnitude} alert at {s3_key_alert}")
    
    except Exception as e:
        print(f"Error processing event {feature.get('id', 'unknown')}: {e}")


def lambda_handler(event, context):
    """Lambda handler for seismic data polling."""
    print("Starting seismic data poll...")
    
    # Fetch data from both sources
    nrcan_events = fetch_nrcan_data()
    usgs_events = fetch_usgs_data()
    
    # Process NRCan events
    for feature in nrcan_events:
        process_event(feature, source='nrcan')
    
    # Process USGS events
    for feature in usgs_events:
        process_event(feature, source='usgs')
    
    total_events = len(nrcan_events) + len(usgs_events)
    print(f"Completed seismic data poll. Processed {total_events} total events.")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Seismic data poll completed',
            'nrcan_events': len(nrcan_events),
            'usgs_events': len(usgs_events)
        })
    }
