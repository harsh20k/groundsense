# GroundSense

An agentic AI system on AWS that answers natural language questions about earthquakes using real-time USGS/NRCan data, historical RAG retrieval, and dynamic map/chart visualizations.

## What It Does

Ask questions like:
- *"How many M4.0+ earthquakes hit Nova Scotia last year?"*
- *"Is today's Vancouver activity unusual?"*
- *"Should Halifax worry about tsunamis from Grand Banks earthquakes?"*

The AI agent autonomously decides which tools to use, fetches real-time and historical data, and responds with answers plus relevant charts and maps.

## Architecture

- **Frontend**: Single-page web app (S3 + CloudFront)
- **Backend**: API Gateway → Lambda → Bedrock Agent (Claude 3.5 Sonnet)
- **Data Pipeline**: Kinesis Data Streams for real-time events, EventBridge for scheduled document ingestion
- **Storage**: DynamoDB (recent data), S3 (historical archive), Bedrock Knowledge Base (RAG for narrative documents)
- **Alerts**: EventBridge proactive monitoring for M5.0+ events → SNS notifications

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

---

For detailed architecture and implementation notes, see `notes/Project Description.md`
