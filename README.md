# GroundSense

AWS-native generative AI application: an Amazon Bedrock Agent with LLM tool use and retrieval-augmented generation (RAG) answers natural-language questions about earthquakes—live seismic APIs, DynamoDB and S3 data, PDF knowledge bases, and data visualization (maps and charts). Serverless architecture with Terraform (infrastructure as code), Python on AWS Lambda, API Gateway, EventBridge, CloudFront and S3 for the static site, and a React single-page app.

## What it does

Ask questions like:

- *"How many M4.0+ earthquakes hit Nova Scotia last year?"*
- *"Is today's Vancouver activity unusual?"*
- *"Should Halifax worry about tsunamis from Grand Banks earthquakes?"*

The agent chooses tools, pulls live and historical data, and answers with text plus maps and charts when useful.

## Architecture

- **Web UI**: React SPA on **S3 + CloudFront** — setup in [deploy/phase_5.md](deploy/phase_5.md)
- **API**: **API Gateway** → **Lambda** (response formatter) → **Amazon Bedrock Agent**
- **Ingestion**: **EventBridge Scheduler** runs pollers; **S3** events fan out to downstream Lambdas
- **Storage**: **DynamoDB** (recent events, TTL), **S3** (archive + documents), **Bedrock Knowledge Base** (RAG over narrative PDFs)
- **Alerts**: Lambda on S3 writes → **SNS** for significant events

## Data sources

All free; no API keys required:

- NRCan FDSN Event API (Canada, 1985–present)
- USGS FDSN Event API (global history)
- USGS real-time feed (~minute cadence upstream)
- Open-Meteo (weather at epicenters)

## Features

- Multi-turn chat with session memory
- Tool use for earthquakes, history, hazards, location context, weather
- Maps and charts in the UI
- RAG over uploaded bulletins and reports
- Bedrock guardrails (e.g. blocking earthquake *prediction* requests)
- Optional email alerts via SNS

## System components

### Data pipeline and analytics

Terraform entrypoint: **`infra/`** (root). Design goal: **low cost** — Lambdas invoked directly (no Kinesis).

| Piece | Role |
|--------|------|
| **`seismic_poller`** | NRCan + USGS → DynamoDB + S3 archive; schedule **`rate(5 minutes)`** (`infra/modules/ingestors/main.tf`) |
| **`document_fetcher`** | GSC PDFs → `documents` bucket; daily **02:00 UTC** (`cron(0 2 * * ? *)`) |
| **DynamoDB** | Recent quakes; default **30-day TTL** (configurable) |
| **S3** | `seismic-archive` (date-partitioned lake), `documents` (PDFs) |
| **`alert`** | On new objects under the alert path, read metadata and publish to **SNS** (set `alert_email` in `terraform.tfvars`) |
| **`kb_sync`** | On new docs in S3, starts a **Knowledge Base ingestion job** when `knowledge_base_id` and `data_source_id` are set |
| **Glue + Athena** | Crawler on the archive; SQL in Athena for historical analysis |

Rough **data-only** AWS bill for light use: on the order of **$0.10–0.50/month** (mostly Lambda, storage, and ad hoc Athena; scheduler and S3 notifications are negligible).

### Knowledge Base (RAG)

Terraform: **`infra/phase2`**. Bedrock Knowledge Base (e.g. OpenSearch Serverless-backed). Walkthrough: [deploy/phase_2.md](deploy/phase_2.md).

### Agent, guardrails, and tools

Terraform: **`infra/phase3`**.

- **Model** (default in Terraform): `us.anthropic.claude-sonnet-4-20250514-v1:0`
- **Guardrails**: topic policies for predictions and similar abuse (`infra/phase3/modules/bedrock_agent`)
- **Tool Lambdas** (`lambda/tools/`): `get_recent_earthquakes`, `analyze_historical_patterns`, `get_hazard_assessment`, `get_location_context`, `fetch_weather_at_epicenter`

Agent setup: [deploy/phase_3.md](deploy/phase_3.md). Example environment checklist and tool checks: [deploy/PHASE_3_STATUS.md](deploy/PHASE_3_STATUS.md).

### Response formatter

Lambda that shapes agent output for the frontend. Terraform: **`infra/phase4`**. [deploy/phase_4.md](deploy/phase_4.md).

### Web app and public API

API Gateway in front of the formatter; static site for the UI. Terraform: **`infra/phase5`**. [deploy/phase_5.md](deploy/phase_5.md). Source: **`frontend/`** (Vite + React).

## Deployment

### Prerequisites

- AWS CLI configured
- Terraform ≥ 1.5
- Python **3.11+** (ingestors and formatter target 3.11; agent tool Lambdas in **`infra/phase3`** use **3.12** in Terraform)

### Terraform directories (apply in order)

Each folder has `terraform.tfvars.example`; use the previous stack’s outputs for the next. Guides under **`deploy/`** match these paths.

- **`infra/`** — storage, ingestors, triggers, analytics  
- **`infra/phase2`** — Knowledge Base  
- **`infra/phase3`** — Bedrock agent + tool Lambdas  
- **`infra/phase4`** — response formatter  
- **`infra/phase5`** — API Gateway + UI hosting  

### Bootstrap the core stack

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit: alert_email; optional knowledge_base_id / data_source_id for kb_sync

terraform init
terraform apply
```

After the root stack, follow the **`deploy/`** guides linked above for each additional `infra/` subfolder you apply.

### Outputs

Run `terraform output` in each directory you applied. The root stack exposes table names, buckets, Lambda names, SNS ARN, Glue DB, and Athena workgroup. Later stacks add invoke URLs, CloudFront domain, etc.

## Testing

### Invoke Lambdas

```bash
aws lambda invoke \
  --function-name groundsense-dev-seismic-poller \
  --payload '{}' \
  response.json

aws lambda invoke \
  --function-name groundsense-dev-document-fetcher \
  --payload '{}' \
  response.json
```

(Replace `groundsense-dev` if you changed `project_name` / `environment`.)

### DynamoDB (recent events)

```bash
aws dynamodb scan \
  --table-name groundsense-dev-earthquakes \
  --max-items 10
```

### Athena (archive)

1. Athena console → workgroup **`groundsense-dev-seismic-analysis`** (or your configured name).
2. Query with partition values that exist in your lake:

```sql
SELECT *
FROM groundsense_dev_seismic_data.data
WHERE year = '2026'
LIMIT 10;
```

## Further reading

- Extended product roadmap and alternatives: [notes/Build Plan.md](notes/Build%20Plan.md)
- Deployment walkthroughs: **`deploy/`** (step-by-step guides and environment status notes)
- Design and session notes: **`notes/`** (e.g. `progress/`)

## Repository layout

```
groundsense/
├── infra/
│   ├── modules/          # storage, ingestors, triggers, analytics, IAM
│   ├── main.tf           # root stack (pipeline + storage + triggers)
│   ├── phase2/           # Knowledge Base
│   ├── phase3/           # Bedrock agent + tool Lambdas
│   ├── phase4/           # response formatter
│   └── phase5/           # API Gateway + S3 + CloudFront
├── frontend/             # Vite + React SPA
├── lambda/
│   ├── alert/
│   ├── document_fetcher/
│   ├── kb_sync/
│   ├── response_formatter/
│   ├── seismic_poller/
│   └── tools/            # five agent tools
├── deploy/               # step-by-step AWS guides
└── notes/                # plans, architecture, progress
```

## License

MIT
