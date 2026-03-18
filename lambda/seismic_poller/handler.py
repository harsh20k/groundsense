"""
Seismic Data Poller Lambda

This Lambda function polls earthquake data from USGS and NRCan APIs and stores
events in DynamoDB (hot storage, 30-day TTL) and S3 (cold archive, lifecycle tiers).

Data Sources:
- USGS: Global earthquake monitoring (real-time GeoJSON feed)
- NRCan: Canadian earthquake monitoring (FDSN text format)

Polling Strategy:
- EventBridge triggers this Lambda every 5 minutes (configurable)
- USGS: Uses pre-computed real-time feed (last hour, updates every 1 min)
- NRCan: Uses FDSN API with custom time range (currently 1 hour)

Time Window Optimization:
- Current: Conservative 1-hour windows (catches everything, some duplication)
- Optimal: Dynamic window = polling_interval + 2min buffer
  * 5-min polling -> 7-min window
  * 1-min polling -> 3-min window
- DynamoDB prevents duplicates via conditional writes

Alert Mechanism:
- Events with magnitude >= 5.0 trigger alerts
- Written to S3 alerts/ prefix for downstream Lambda processing
- Target latency: ~2 minutes from earthquake to alert (1-min polling)
"""

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
    """Fetch recent earthquake data from NRCan FDSN API.
    
    Time Window Strategy:
    - NRCan uses FDSN text format (pipe-delimited), which supports custom time ranges
    - Current: 1-hour window (conservative, catches all events with redundancy)
    - Optimal for 5-min polling: 7 minutes (5 min interval + 2 min buffer)
    - Optimal for 1-min polling: 3 minutes (1 min interval + 2 min buffer)
    - Buffer accounts for: clock skew, API delays, event processing time
    - DynamoDB conditional writes prevent duplicates across overlapping windows
    """
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(hours=1)  # TODO: Optimize to match polling frequency
    
    url = (
        f"https://www.earthquakescanada.nrcan.gc.ca/fdsnws/event/1/query?"
        f"format=text&"
        f"starttime={start_time.isoformat()}&"
        f"endtime={end_time.isoformat()}&"
        f"minmagnitude=0.0"
    )
    
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            text_data = response.read().decode('utf-8')
            lines = text_data.strip().split('\n')
            
            # Skip header line that starts with #
            events = []
            for line in lines:
                if line.startswith('#') or not line.strip():
                    continue
                
                # Parse pipe-delimited format: EventID|Time|Lat|Lon|Depth|MagType|Mag|Location
                parts = line.split('|')
                if len(parts) < 8:
                    continue
                
                try:
                    event_id = parts[0].strip()
                    time_str = parts[1].strip()
                    latitude = float(parts[2].strip())
                    longitude = float(parts[3].strip())
                    depth = float(parts[4].strip())
                    mag_type = parts[5].strip()
                    magnitude = float(parts[6].strip())
                    place = parts[7].strip()
                    
                    # Convert to milliseconds timestamp
                    time_obj = datetime.fromisoformat(time_str.replace('Z', '+00:00'))
                    time_ms = int(time_obj.timestamp() * 1000)
                    
                    # Convert to GeoJSON-like structure that process_event() expects
                    feature = {
                        'id': f"nrcan_{event_id}",
                        'type': 'Feature',
                        'properties': {
                            'mag': magnitude,
                            'place': place,
                            'time': time_ms,
                            'type': 'earthquake',
                            'magType': mag_type,
                            'url': f"https://www.earthquakescanada.nrcan.gc.ca/stndon/NEDB-BNDS/bulletin-en.php?evid={event_id}"
                        },
                        'geometry': {
                            'type': 'Point',
                            'coordinates': [longitude, latitude, depth]
                        }
                    }
                    events.append(feature)
                except (ValueError, IndexError) as e:
                    print(f"Error parsing NRCan line: {line} - {e}")
                    continue
            
            print(f"Fetched {len(events)} events from NRCan")
            return events
    except urllib.error.URLError as e:
        print(f"Error fetching NRCan data: {e}")
        return []


def fetch_usgs_data():
    """Fetch recent earthquake data from USGS real-time feed.
    
    Time Window Strategy:
    - Uses USGS pre-computed real-time feed (all_hour.geojson)
    - Feed updates every 1 minute and contains last 1 hour of events
    - No custom time filtering needed - already optimized by USGS
    - Fast response (~100-300ms) - designed for real-time monitoring
    - Alternative: USGS FDSN endpoint supports custom ranges but slower (2-5s)
    """
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
    """Lambda handler for seismic data polling.
    
    Polling Frequency Configuration:
    - Current: Every 5 minutes (configured in EventBridge schedule)
    - Recommended for alerts: Every 1 minute (matches USGS feed update rate)
    - Faster polling (<1 min) provides no benefit due to seismic processing delays
    
    Alert Latency Timeline (1-min polling):
    - T+0:00: Earthquake occurs
    - T+0:30: Detected by seismometers
    - T+1:00: Appears in USGS feed
    - T+1:30: Lambda polls and processes
    - T+2:00: Alert sent (if M5.0+)
    
    Duplicate Prevention:
    - DynamoDB conditional writes (attribute_not_exists) prevent duplicates
    - Safe to use overlapping time windows across polling cycles
    - Each event processed exactly once, regardless of window overlap
    """
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
