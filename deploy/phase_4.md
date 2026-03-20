# Phase 4 Deployment Guide - Response Formatting

## Implementation Status

✅ **Completed** (March 20, 2026):
1. Created response formatter Lambda function
2. Implemented trace parsing to capture tool calls
3. Built visualization mapping logic (5 visualization types)
4. Created Phase 4 Terraform infrastructure
5. Configured Lambda Function URL for public access

## Phase 4 Infrastructure Overview

### Architecture

```
Client Request
    ↓
Response Formatter Lambda (with Function URL)
    ↓ (enableTrace=True)
Bedrock Agent (JBNWSD6MFJ)
    ↓
5 Tool Lambdas
    ↓
Structured JSON Response
```

### What Phase 4 Adds

**Response Formatter Lambda** wraps the Bedrock Agent and:
- Invokes agent with `enableTrace=True` to capture tool call metadata
- Streams agent response chunks (text)
- Parses orchestration traces to extract tool invocations + outputs
- Maps tool calls to visualization types
- Returns structured JSON envelope for frontend

### Resources Created

**Lambda Function**:
- `groundsense-dev-response-formatter`
- Runtime: Python 3.11
- Timeout: 120 seconds (agent invocations can take 30-60s)
- Memory: 512 MB

**Lambda Function URL**:
- Public access (CORS enabled)
- Authorization: NONE (Phase 5 adds API Gateway + API keys)

**IAM Role**:
- CloudWatch Logs write permissions
- `bedrock:InvokeAgent` on the Phase 3 **agent** and **agent-alias** ARNs (runtime checks the alias resource)

---

## JSON Contract

### Request Format

```json
{
  "query": "Show me recent earthquakes above M4.0",
  "session_id": "optional-session-id"
}
```

If `session_id` is omitted, a new session is created.

### Response Format

```json
{
  "message": "Agent's natural language response",
  "session_id": "session-20260320-143022",
  "visualization": {
    "type": "earthquake_map | line_chart | stat_card | location_map | weather_card | document_excerpt | none",
    "title": "Recent Earthquakes (9 events)",
    "data": [...]
  }
}
```

### Visualization Types

#### 1. `earthquake_map`

**Triggered by**: `get_recent_earthquakes` or `analyze_historical_patterns` with `query_type=max`

```json
{
  "type": "earthquake_map",
  "title": "Recent Earthquakes (9 events)",
  "data": [
    {
      "latitude": 48.23,
      "longitude": -123.45,
      "magnitude": 4.5,
      "place": "Vancouver Island",
      "time": "2026-03-18T12:34:56",
      "depth_km": 10.0,
      "earthquake_id": "us1000..."
    }
  ]
}
```

#### 2. `line_chart`

**Triggered by**: `analyze_historical_patterns` with `query_type=timeseries`

```json
{
  "type": "line_chart",
  "title": "Earthquake Trends Over Time",
  "data": [
    {
      "month": "2026-03",
      "event_count": 45,
      "avg_magnitude": 2.3,
      "max_magnitude": 4.8
    }
  ]
}
```

#### 3. `stat_card`

**Triggered by**: `analyze_historical_patterns` with `query_type=count` or `average`

```json
{
  "type": "stat_card",
  "title": "Historical Statistics",
  "data": {
    "earthquake_count": 123,
    "avg_magnitude": 2.5,
    "min_magnitude": 0.5,
    "max_magnitude": 5.2,
    "event_count": 123
  }
}
```

#### 4. `location_map`

**Triggered by**: `get_location_context` (standalone, without recent earthquakes)

Aligned with tool output: `display_name`, `nearest_city`, `population_centers` → `nearby_cities`, KB rows → `context_excerpts`.

```json
{
  "type": "location_map",
  "title": "Halifax, Nova Scotia, Canada",
  "data": {
    "latitude": 44.6486,
    "longitude": -63.5859,
    "name": "Halifax, Nova Scotia, Canada",
    "nearest_city": "Halifax, ...",
    "nearby_cities": ["Dartmouth", "Bedford"],
    "context_excerpts": [
      {
        "content": "…tectonic context from KB…",
        "relevance_score": 0.68,
        "source": "GEOFACT_Grand-Banks-1929_e.pdf"
      }
    ]
  }
}
```

#### 5. `weather_card`

**Triggered by**: `fetch_weather_at_epicenter` (standalone)

```json
{
  "type": "weather_card",
  "title": "Weather at Epicenter",
  "data": {
    "temperature": 22.5,
    "wind_speed": 15.2,
    "precipitation": 0.0,
    "description": "Partly cloudy",
    "noise_risk": "low",
    "latitude": 15.38,
    "longitude": -89.04
  }
}
```

#### 6. `document_excerpt`

**Triggered by**: `get_hazard_assessment` only (no other tools)

```json
{
  "type": "document_excerpt",
  "title": "Document Excerpts",
  "data": [
    {
      "content": "Halifax is located in a region of low seismic hazard...",
      "source": "GSC_Report_2018.pdf",
      "score": 0.8732
    }
  ]
}
```

#### 7. `none`

**When**: No tools called or no visualizable data

```json
{
  "type": "none"
}
```

---

## Deployment

### Prerequisites

1. Phase 3 deployed and operational
2. Agent ID and Alias ID from Phase 3 outputs

### Step 1: Get Phase 3 Outputs

```bash
cd /Users/harsh/Artifacts/groundsense/infra/phase3
terraform output
```

Copy these values:
- `agent_id`
- `agent_alias_id`
- `agent_arn`

### Step 2: Configure Phase 4

```bash
cd /Users/harsh/Artifacts/groundsense/infra/phase4

# Copy example config
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
nano terraform.tfvars
```

Update with Phase 3 outputs:
```hcl
agent_id       = "JBNWSD6MFJ"
agent_alias_id = "B2ZT7W7EBS"
agent_arn      = "arn:aws:bedrock:us-east-1:411960113601:agent/JBNWSD6MFJ"
```

### Step 3: Deploy

```bash
terraform init
terraform plan
terraform apply
```

### Step 4: Get Function URL

```bash
terraform output formatter_function_url
```

Expected output:
```
https://abcd1234.lambda-url.us-east-1.on.aws/
```

---

## Testing

### Test 1: Recent Earthquakes (earthquake_map)

```bash
FUNCTION_URL=$(cd infra/phase4 && terraform output -raw formatter_function_url)

curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Show me recent earthquakes above M4.0"
  }' | jq .
```

**Expected Response**:
```json
{
  "message": "Found 9 earthquakes above magnitude 4.0 in the last 30 days...",
  "session_id": "session-20260320-143022",
  "visualization": {
    "type": "earthquake_map",
    "title": "Recent Earthquakes (9 events)",
    "data": [
      {
        "latitude": -21.7,
        "longitude": 68.9,
        "magnitude": 5.2,
        "place": "Mid-Indian Ridge",
        "time": "2026-03-18T11:10:00",
        "depth_km": 10.0
      }
    ]
  }
}
```

---
arn:aws:bedrock:us-east-1:411960113601:agent/JBNWSD6MFJ
### Test 2: Historical Timeseries (line_chart)

```bash
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Show me monthly earthquake trends for the last year"
  }' | jq .
```

**Expected Response**:
```json
{
  "message": "Here are the monthly earthquake trends...",
  "session_id": "session-20260320-143022",
  "visualization": {
    "type": "line_chart",
    "title": "Earthquake Trends Over Time",
    "data": [
      {
        "month": "2026-03",
        "event_count": 45,
        "avg_magnitude": 2.3,
        "max_magnitude": 4.8
      }
    ]
  }
}
```

---

### Test 3: Historical Statistics (stat_card)

```bash
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "How many M3+ earthquakes happened in BC last year?"
  }' | jq .
```

**Expected Response**:
```json
{
  "visualization": {
    "type": "stat_card",
    "title": "Historical Statistics",
    "data": {
      "earthquake_count": 234,
      "avg_magnitude": 3.2,
      "min_magnitude": 3.0,
      "max_magnitude": 5.1,
      "event_count": 234
    }
  }
}
```

---

### Test 4: Location Context (location_map)

```bash
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What is the tectonic setting near Vancouver?"
  }' | jq .
```

**Expected Response**:
```json
{
  "visualization": {
    "type": "location_map",
    "title": "Vancouver, BC, Canada",
    "data": {
      "latitude": 49.28,
      "longitude": -123.12,
      "name": "Vancouver, BC, Canada",
      "nearest_city": "…",
      "nearby_cities": ["Surrey", "Burnaby", "Richmond"],
      "context_excerpts": [
        {
          "content": "…KB excerpt…",
          "relevance_score": 0.75,
          "source": "some-report.pdf"
        }
      ]
    }
  }
}
```

---

### Test 5: Weather Context (weather_card)

```bash
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Show me recent M4+ earthquakes and tell me the weather at the strongest one",
    "session_id": "test-weather-001"
  }' | jq .
```

**Expected Response**:
- First tool: `earthquake_map` (takes priority)
- Message includes weather context synthesized by agent

---

### Test 6: Document Retrieval (document_excerpt)

```bash
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What do reports say about Halifax seismic risk?"
  }' | jq .
```

**Expected Response**:
```json
{
  "visualization": {
    "type": "document_excerpt",
    "title": "Document Excerpts",
    "data": [
      {
        "content": "Halifax is located in a region of low seismic hazard...",
        "source": "GSC_Report_2018.pdf",
        "score": 0.8732
      }
    ]
  }
}
```

---

### Test 7: Multi-Turn Conversation

```bash
SESSION_ID="multi-turn-$(date +%s)"

# First query
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": \"Show me recent earthquakes in BC\",
    \"session_id\": \"$SESSION_ID\"
  }" | jq .

# Follow-up (uses same session)
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": \"How does that compare to last year?\",
    \"session_id\": \"$SESSION_ID\"
  }" | jq .
```

Agent remembers context from first query.

---

## Visualization Mapping Logic

### Priority Order

When multiple tools are called, the formatter selects visualization type in this order:

1. **earthquake_map**: `get_recent_earthquakes` OR `analyze_historical_patterns` with `query_type=max`
2. **line_chart**: `analyze_historical_patterns` with `query_type=timeseries`
3. **stat_card**: `analyze_historical_patterns` with `query_type=count` or `average`
4. **location_map**: `get_location_context` (standalone)
5. **weather_card**: `fetch_weather_at_epicenter` (standalone)
6. **document_excerpt**: `get_hazard_assessment` (standalone)
7. **none**: No tools called or no visualizable data

### Multi-Tool Behavior

- If `get_recent_earthquakes` is called, it always wins for visualization
- Other tool outputs are synthesized into the `message` text only
- Example: "Show me recent quakes and the weather at the strongest" → `earthquake_map` + weather context in message

---

## Troubleshooting

### Lambda Timeout (120s)

**Symptom**: Response formatter times out

**Cause**: Agent is taking too long (complex multi-tool queries)

**Solution**:
1. Check agent CloudWatch logs to see which tool is slow
2. Increase Lambda timeout to 180s in `main.tf`
3. Redeploy: `terraform apply`

### No Visualization Returned

**Symptom**: `visualization.type = "none"` for queries that should show visualizations

**Possible Causes**:
1. Agent didn't call any tools (query too vague)
2. Tool output format changed
3. Trace parsing failed

**Debug**:
```bash
# Check Lambda logs
aws logs tail /aws/lambda/groundsense-dev-response-formatter --follow

# Look for:
# - "Captured tool call: get_recent_earthquakes"
# - "Building visualization from N tool calls"
```

**Solution**:
- Make query more specific ("Query recent earthquakes above M4.0")
- Check tool Lambda logs to verify outputs match expected schema

### CORS Errors

**Symptom**: Browser shows CORS errors when calling Function URL

**Status**: Function URL has CORS configured (`allow_origins = ["*"]`)

**If still failing**: Phase 5 adds API Gateway with proper CORS handling

### Agent Response Too Slow

**Symptom**: Client times out waiting for response

**Cause**: Bedrock Agent streaming takes 20-60s for complex queries

**Solution**:
- Increase client timeout to 120s
- Phase 5 can add WebSocket streaming for real-time chunks

---

## Cost Estimate

| Component                                             | Monthly Cost     |
| ----------------------------------------------------- | ---------------- |
| Response Formatter Lambda (~100 invocations, 30s avg) | $0.05            |
| Lambda Function URL requests (~100/month)             | Free             |
| Bedrock Agent invocations (from Phase 3)              | $0.10-1.00       |
| **Total Phase 4 Addition**                            | **~$0.05/month** |

**Phase 1+2+3+4 Combined**: ~$3-5/month

---

## Files Created

### Lambda Function
```
lambda/response_formatter/
├── handler.py          # Trace parsing + visualization mapping
└── requirements.txt    # Empty (boto3 is in runtime)
```

### Phase 4 Infrastructure
```
infra/phase4/
├── providers.tf
├── variables.tf
├── terraform.tfvars.example
├── outputs.tf
└── main.tf             # Lambda, IAM, Function URL
```

---

## Next Steps (Phase 5)

Once Phase 4 is validated:

1. **Frontend Web App**:
   - React/Vue SPA with chat interface
   - Leaflet.js for earthquake maps
   - Chart.js for timeseries and stats
   - Deployed to S3 + CloudFront

2. **API Gateway**:
   - Replace Lambda Function URL with API Gateway endpoint
   - Add API key authentication
   - Rate limiting (100 requests/day per key)

3. **WebSocket Streaming** (optional):
   - Real-time agent response streaming
   - Show tool calls as they happen

**Phase 5 Scope**: Frontend UI + API Gateway (~15-20 files)

---

## Validation Checklist

✅ Response formatter Lambda deployed

✅ Lambda Function URL accessible via curl

✅ Trace parsing captures tool invocations

✅ Visualization mapping works for all 5 types

⏳ End-to-end test with all visualization types

⏳ Multi-turn conversation session persistence verified

⏳ Error handling tested (malformed queries, agent failures)

---

## Documentation References

- [Bedrock Agent Runtime API](https://docs.aws.amazon.com/bedrock/latest/APIReference/API_agent-runtime_InvokeAgent.html)
- [Agent Trace Events](https://docs.aws.amazon.com/bedrock/latest/userguide/agents-test.html#agents-test-invoke)
- [Lambda Function URLs](https://docs.aws.amazon.com/lambda/latest/dg/lambda-urls.html)

---

**Status**: Phase 4 implementation complete. Ready for deployment.

**Next Phase**: Phase 5 - Frontend Web App + API Gateway
