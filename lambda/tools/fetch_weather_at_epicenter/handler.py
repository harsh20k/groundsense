"""
Fetch Weather at Epicenter Tool

Lambda function that retrieves current or historical weather conditions at earthquake
epicenters using the Open-Meteo API (free, no API key required).

Input Parameters:
- latitude: Epicenter latitude (required)
- longitude: Epicenter longitude (required)
- event_time: ISO 8601 datetime string for historical weather (optional, e.g. "2024-03-15T14:30:00")

Output:
- temperature, weather_condition, wind_speed, precipitation, seismic_noise_risk assessment
"""

import json
import urllib.request
import urllib.parse
from datetime import datetime, timezone


WMO_CODES = {
    0: "Clear sky",
    1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
    45: "Fog", 48: "Icy fog",
    51: "Light drizzle", 53: "Moderate drizzle", 55: "Dense drizzle",
    61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain",
    71: "Slight snow", 73: "Moderate snow", 75: "Heavy snow",
    77: "Snow grains",
    80: "Slight showers", 81: "Moderate showers", 82: "Violent showers",
    85: "Slight snow showers", 86: "Heavy snow showers",
    95: "Thunderstorm", 96: "Thunderstorm with hail", 99: "Thunderstorm with heavy hail",
}


def _seismic_noise_risk(weather_code, wind_speed, precipitation):
    """
    Assess how current weather may affect seismometer noise levels.
    Returns: 'low' | 'moderate' | 'high'
    """
    factors = []
    if wind_speed is not None and wind_speed > 40:
        factors.append("strong winds")
    if precipitation is not None and precipitation > 5:
        factors.append("heavy precipitation")
    if weather_code in (95, 96, 99):
        factors.append("thunderstorm")

    if len(factors) >= 2:
        level = "high"
    elif factors:
        level = "moderate"
    else:
        level = "low"

    return {"level": level, "factors": factors}


def _http_get(url, params):
    full_url = f"{url}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(full_url, headers={"User-Agent": "GroundSense/1.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode())


def fetch_current_weather(lat, lon):
    data = _http_get("https://api.open-meteo.com/v1/forecast", {
        "latitude": lat,
        "longitude": lon,
        "current_weather": True,
        "hourly": "precipitation",
        "forecast_days": 1,
        "timezone": "UTC",
    })
    cw = data.get("current_weather", {})
    hourly = data.get("hourly", {})

    # Get precipitation for the current hour
    current_hour_idx = 0
    try:
        now_str = cw.get("time", "")
        times = hourly.get("time", [])
        if now_str and times:
            current_hour_idx = next(
                (i for i, t in enumerate(times) if t.startswith(now_str[:13])), 0
            )
    except Exception:
        pass

    precip_list = hourly.get("precipitation", [])
    precipitation = precip_list[current_hour_idx] if precip_list else None

    return {
        "temperature_c": cw.get("temperature"),
        "wind_speed_kmh": cw.get("windspeed"),
        "wind_direction_deg": cw.get("winddirection"),
        "weather_code": cw.get("weathercode"),
        "weather_description": WMO_CODES.get(cw.get("weathercode"), "Unknown"),
        "precipitation_mm": precipitation,
        "observation_time": cw.get("time"),
        "is_day": bool(cw.get("is_day", 1)),
    }


def fetch_historical_weather(lat, lon, event_dt):
    date_str = event_dt.strftime("%Y-%m-%d")
    hour = event_dt.hour

    data = _http_get("https://archive-api.open-meteo.com/v1/archive", {
        "latitude": lat,
        "longitude": lon,
        "start_date": date_str,
        "end_date": date_str,
        "hourly": "temperature_2m,precipitation,wind_speed_10m,wind_direction_10m,weather_code",
        "timezone": "UTC",
    })

    hourly = data.get("hourly", {})
    times = hourly.get("time", [])

    # Find the closest hour
    target = f"{date_str}T{hour:02d}:00"
    idx = next((i for i, t in enumerate(times) if t == target), min(hour, len(times) - 1))

    def _get(key):
        vals = hourly.get(key, [])
        return vals[idx] if idx < len(vals) else None

    wcode = _get("weather_code")
    return {
        "temperature_c": _get("temperature_2m"),
        "wind_speed_kmh": _get("wind_speed_10m"),
        "wind_direction_deg": _get("wind_direction_10m"),
        "weather_code": wcode,
        "weather_description": WMO_CODES.get(int(wcode), "Unknown") if wcode is not None else "Unknown",
        "precipitation_mm": _get("precipitation"),
        "observation_time": times[idx] if idx < len(times) else None,
        "is_historical": True,
    }


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
        "actionGroup": "WeatherContext",
        "function": "fetch_weather_at_epicenter",
        "parameters": [
            {"name": "latitude", "value": "18.2"},
            {"name": "longitude", "value": "-63.1"},
            {"name": "event_time", "value": "2024-03-15T14:30:00"}
        ]
    }
    """
    print(f"Received event: {json.dumps(event)}")

    params = {p["name"]: p["value"] for p in event.get("parameters", []) if p.get("name") and p.get("value")}

    try:
        lat = float(params["latitude"])
        lon = float(params["longitude"])
    except (KeyError, ValueError, TypeError):
        return _success(event, {"error": "latitude and longitude are required numeric parameters"})

    event_time_str = params.get("event_time", "").strip()
    event_dt = None

    if event_time_str:
        for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
            try:
                event_dt = datetime.strptime(event_time_str, fmt).replace(tzinfo=timezone.utc)
                break
            except ValueError:
                continue
        if event_dt is None:
            return _success(event, {"error": f"Cannot parse event_time: {event_time_str}. Use ISO 8601 format."})

    try:
        if event_dt:
            weather = fetch_historical_weather(lat, lon, event_dt)
        else:
            weather = fetch_current_weather(lat, lon)
    except Exception as e:
        return _success(event, {"error": f"Weather API error: {str(e)}", "latitude": lat, "longitude": lon})

    noise_risk = _seismic_noise_risk(
        weather.get("weather_code"),
        weather.get("wind_speed_kmh"),
        weather.get("precipitation_mm"),
    )

    result = {
        "location": {"latitude": lat, "longitude": lon},
        "weather": weather,
        "seismic_noise_risk": noise_risk,
        "notes": {
            "high_noise": "Heavy rain/wind increases seismometer background noise, may mask small aftershocks",
            "landslide_risk": "Combine precipitation data with slope maps for landslide assessment",
            "visibility": "Poor weather complicates field response and aerial surveys",
        },
    }

    print(f"Returning weather for ({lat}, {lon}), noise_risk={noise_risk['level']}")
    return _success(event, result)
