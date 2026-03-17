# GroundSense

An agentic AI application on AWS that answers natural language questions about earthquakes using real-time seismic (API) data, historical RAG retrieval (pdf documents), and dynamic map/chart visualizations.

## What It Does

Ask questions like:
- *"How many M4.0+ earthquakes hit Nova Scotia last year?"*
- *"Is today's Vancouver activity unusual?"*
- *"Should Halifax worry about tsunamis from Grand Banks earthquakes?"*

The AI agent autonomously decides which tools to use, fetches real-time and historical data, and responds with answers plus relevant charts and maps.

## Architecture

- **Frontend**: Single-page web app (S3 + CloudFront)
- **Backend**: API Gateway → Lambda → Bedrock Agent 
- **Data Pipeline**: EventBridge Scheduler for ingestors, S3 event notifications for fanout
- **Storage**: DynamoDB (recent data), S3 (historical archive), Bedrock Knowledge Base (RAG for narrative documents)
- **Alerts**: S3-triggered Lambda → SNS notifications for M5.0+ events

## Data Sources

All free, no API keys required:
- NRCan FDSN Event API (Canadian seismic data, 1985-present)
- USGS FDSN Event API (global historical data)
- USGS Real-Time Feed (updates every minute)
- Open-Meteo (weather context)

## Key Features

- Multi-turn conversations with session memory
- Autonomous tool selection and reasoning
- Dynamic visualizations (maps and charts)
- RAG-based historical context
- Guardrails to block earthquake prediction requests
- Proactive alerts for significant events

## Phase 1: Data Pipeline (Implemented)

✅ **Architecture**: Version 4 (Simplest/Cheapest - Direct Invocation)

### Components

1. **Ingestors** (Lambda + EventBridge Scheduler):
   - `seismic_poller`: Fetches NRCan + USGS data every minute → writes to DynamoDB + S3
   - `document_fetcher`: Fetches GSC PDFs daily → writes to S3

2. **Storage**:
   - DynamoDB: Recent earthquakes (30-day TTL)
   - S3 `seismic-archive`: Historical data lake (partitioned by date)
   - S3 `documents`: PDF reports and bulletins

3. **Triggers** (S3 event notifications):
   - `alert` Lambda: M5.0+ events → SNS topic (Phase 6 stub)
   - `kb_sync` Lambda: New documents → Bedrock KB sync (Phase 2 stub)

4. **Analytics**:
   - Glue Crawler: Catalogs S3 data lake
   - Athena: SQL queries over historical data

### Cost Estimate
~$0.10–0.50/month (EventBridge Scheduler is free, S3 notifications are free, only pay for Lambda execution + storage)

## Deployment

### Prerequisites
- AWS CLI configured
- Terraform >= 1.5
- Python 3.11

### Deploy Infrastructure

```bash
cd infra

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# Initialize Terraform
terraform init

# Deploy
terraform apply
```

### Outputs

After deployment, Terraform will output:
- DynamoDB table name
- S3 bucket names
- Lambda function names
- SNS topic ARN
- Glue database and Athena workgroup names

### Testing

#### Manual Lambda Invocation

```bash
# Test seismic poller
aws lambda invoke \
  --function-name groundsense-dev-seismic-poller \
  --payload '{}' \
  response.json

# Test document fetcher
aws lambda invoke \
  --function-name groundsense-dev-document-fetcher \
  --payload '{}' \
  response.json
```

#### Query Recent Earthquakes (DynamoDB)

```bash
aws dynamodb scan \
  --table-name groundsense-dev-earthquakes \
  --max-items 10
```

#### Query Historical Data (Athena)

1. Navigate to Athena console
2. Select workgroup: `groundsense-dev-seismic-analysis`
3. Run query:

```sql
SELECT * 
FROM groundsense_dev_seismic_data.data
WHERE year = 2026 
LIMIT 10;
```

## Next Steps

### Phase 2: Knowledge Base (RAG Setup)
- Create Bedrock Knowledge Base + OpenSearch Serverless
- Wire up `kb_sync` Lambda to start ingestion jobs
- Test retrieval quality

### Phase 3: Agent & Tools
- Implement 5 Lambda tools for the agent
- Configure Bedrock Agent with Claude 3.5 Sonnet
- Add Guardrails

### Phase 4-7
See [Build Plan](notes/Build%20Plan.md) for full roadmap

## Project Structure

```
groundsense/
├── infra/                    # Terraform infrastructure
│   ├── modules/
│   │   ├── storage/          # DynamoDB + S3
│   │   ├── ingestors/        # Poller Lambdas
│   │   ├── triggers/         # Alert + KB sync Lambdas
│   │   └── analytics/        # Glue + Athena
│   ├── main.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── lambda/                   # Lambda function source code
│   ├── seismic_poller/
│   ├── document_fetcher/
│   ├── alert/
│   └── kb_sync/
└── notes/                    # Project documentation
    └── Build Plan.md
```

## License

MIT

---
