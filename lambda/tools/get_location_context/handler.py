"""
Get Location Context Tool

Lambda function that provides geographic and geological context about earthquake locations
by combining Nominatim geocoding with the Bedrock Knowledge Base.

Input Parameters:
- location_name: Place name to geocode (e.g., "Vancouver", "Cascadia Subduction Zone")
- latitude: Latitude coordinate (alternative to location_name)
- longitude: Longitude coordinate (alternative to location_name)
- max_kb_results: Maximum Knowledge Base chunks to return (default: 5)

Output:
- coordinates, nearest_city, tectonic_context from KB, population_centers
"""

import json
import os
import urllib.request
import urllib.parse
import boto3

bedrock_agent_runtime = boto3.client('bedrock-agent-runtime')

KNOWLEDGE_BASE_ID = os.environ.get('KNOWLEDGE_BASE_ID', 'GMWMMJW0TE')
NOMINATIM_URL = "https://nominatim.openstreetmap.org"
USER_AGENT = "GroundSense-EarthquakeMonitor/1.0"


def _http_get(url, params=None):
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode())


def geocode(location_name):
    """Forward geocode a place name → (lat, lon, display_name)."""
    results = _http_get(f"{NOMINATIM_URL}/search", {
        "q": location_name,
        "format": "json",
        "limit": 1,
        "addressdetails": 1,
    })
    if not results:
        return None
    r = results[0]
    return {
        "latitude": float(r["lat"]),
        "longitude": float(r["lon"]),
        "display_name": r.get("display_name", ""),
    }


def reverse_geocode(lat, lon):
    """Reverse geocode coordinates → nearest place description."""
    try:
        result = _http_get(f"{NOMINATIM_URL}/reverse", {
            "lat": lat,
            "lon": lon,
            "format": "json",
            "zoom": 10,
        })
        return result.get("display_name", f"{lat:.4f}°, {lon:.4f}°")
    except Exception:
        return f"{lat:.4f}°, {lon:.4f}°"


def nearby_cities(lat, lon, radius_km=200):
    """Find major cities within radius_km of coordinates."""
    try:
        results = _http_get(f"{NOMINATIM_URL}/search", {
            "q": "city",
            "format": "json",
            "limit": 5,
            "addressdetails": 1,
            "viewbox": f"{lon - 2},{lat + 2},{lon + 2},{lat - 2}",
            "bounded": 1,
        })
        cities = []
        for r in results:
            if r.get("type") in ("city", "town", "village", "administrative"):
                cities.append(r.get("display_name", "").split(",")[0].strip())
        return cities[:5]
    except Exception:
        return []


def query_kb(query, max_results):
    """Query Bedrock Knowledge Base for regional seismic context."""
    try:
        response = bedrock_agent_runtime.retrieve(
            knowledgeBaseId=KNOWLEDGE_BASE_ID,
            retrievalQuery={"text": query},
            retrievalConfiguration={
                "vectorSearchConfiguration": {"numberOfResults": max_results}
            },
        )
        results = []
        for r in response.get("retrievalResults", []):
            uri = r.get("location", {}).get("s3Location", {}).get("uri", "")
            filename = uri.split("/")[-1] if uri else ""
            results.append({
                "content": r.get("content", {}).get("text", ""),
                "relevance_score": round(r.get("score", 0.0), 4),
                "source": filename,
            })
        return results
    except Exception as e:
        return [{"error": str(e)}]


def _success(event, body):
    return {
        "response": {
            "actionGroup": event.get("actionGroup"),
            "function": event.get("function"),
            "functionResponse": {
                "responseBody": {"TEXT": {"body": json.dumps(body)}}
            },
        }
    }


def lambda_handler(event, context):
    """
    Lambda handler for Bedrock Agent tool invocation.

    Expected event structure:
    {
        "actionGroup": "LocationIntelligence",
        "function": "get_location_context",
        "parameters": [
            {"name": "location_name", "value": "Vancouver"},
            {"name": "max_kb_results", "value": "5"}
        ]
    }
    """
    print(f"Received event: {json.dumps(event)}")

    params = {p["name"]: p["value"] for p in event.get("parameters", []) if p.get("name") and p.get("value")}

    location_name = params.get("location_name", "").strip()
    max_kb_results = int(params.get("max_kb_results", "5"))

    try:
        lat = float(params["latitude"]) if "latitude" in params else None
        lon = float(params["longitude"]) if "longitude" in params else None
    except (ValueError, TypeError):
        lat = lon = None

    if not location_name and (lat is None or lon is None):
        return _success(event, {"error": "Provide location_name or both latitude and longitude"})

    coords = None
    display_name = ""

    if location_name:
        geo = geocode(location_name)
        if geo:
            lat, lon = geo["latitude"], geo["longitude"]
            display_name = geo["display_name"]
        else:
            return _success(event, {"error": f"Could not geocode location: {location_name}"})
    else:
        display_name = reverse_geocode(lat, lon)

    nearest_city = reverse_geocode(lat, lon)
    population_centers = nearby_cities(lat, lon)

    kb_query = f"seismic hazards tectonic setting fault systems earthquakes near {display_name or f'{lat:.2f}N {lon:.2f}W'}"
    tectonic_context = query_kb(kb_query, max_kb_results)

    result = {
        "query": location_name or f"{lat}, {lon}",
        "coordinates": {"latitude": lat, "longitude": lon},
        "display_name": display_name,
        "nearest_city": nearest_city,
        "population_centers": population_centers,
        "tectonic_context": tectonic_context,
    }

    print(f"Returning location context for {display_name}")
    return _success(event, result)
