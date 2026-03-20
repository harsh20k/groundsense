# Phase 3 Deployment Status

**Date**: March 19, 2026  
**Environment**: AWS Academy Lab (groundsense-dev)

## Current Deployment State

### ✅ Phase 1: Data Pipeline (DEPLOYED)

**Infrastructure Status**: Fully deployed and operational

**Components**:
- Storage: DynamoDB, S3 (seismic-archive, documents)
- Analytics: Glue Database, Glue Crawler, Athena Workgroup
- Ingestors: `seismic-poller` Lambda (USGS hourly ingest)
- Triggers: EventBridge schedule (hourly), SNS alerts

**Verification**:
```bash
$ cd infra && terraform output
alert_lambda_function_name = "groundsense-dev-alert"
athena_workgroup_name = "groundsense-dev-seismic-analysis"
dynamodb_table_name = "groundsense-dev-earthquakes"
glue_database_name = "groundsense_dev_seismic_data"
seismic_archive_bucket_name = "groundsense-dev-seismic-archive"
seismic_poller_function_name = "groundsense-dev-seismic-poller"
```

### ✅ Phase 2: RAG Knowledge Base (DEPLOYED)

**Status**: Bedrock Knowledge Base operational with OpenSearch Serverless

**Knowledge Base ID**: `GMWMMJW0TE`

### ⏳ Phase 3: Bedrock Agent & Tools (PARTIALLY DEPLOYED)

**What's Working**:
1. ✅ **Lambda Tool 1**: `get_recent_earthquakes` (DynamoDB queries)
   - Successfully tested with manual invocation
   - Returns real earthquake data from DynamoDB
   
2. ✅ **Lambda Tool 2**: `analyze_historical_patterns` (Athena queries)  
   - **Configuration Fixed**: Athena bucket issue resolved
   - IAM permissions enhanced (full S3 access for Athena)
   - **Blocked on**: Glue table not created yet (see below)
   
3. ❓ **Lambda Tool 3**: `get_hazard_assessment` (Bedrock KB)
   - Not yet tested

**What's NOT Working**:

#### Issue: Athena Queries Fail - No Glue Table

**Error**:
```
TABLE_NOT_FOUND: Table 'awsdatacatalog.groundsense_dev_seismic_data.earthquakes' does not exist
```

**Root Cause**: Data pipeline prerequisites not met
- Glue Crawler creates the table by cataloging data in S3
- Crawler needs data to exist first: `s3://groundsense-dev-seismic-archive/data/`
- Data is written by `seismic-poller` Lambda (runs hourly)

**Timeline Dependencies**:
1. ⏳ **USGS Ingestor** (`seismic-poller`) must run first
   - Scheduled: Hourly via EventBridge
   - Writes to: DynamoDB + archives to S3
   - **Status**: Unknown when last run (no CloudWatch Logs access)

2. ⏳ **Glue Crawler** must run after data exists
   - Scheduled: Daily at 3am UTC
   - Creates: `earthquakes` table in Glue Catalog
   - **Status**: Not confirmed if run yet

### 🚫 Phase 3: Bedrock Agent (BLOCKED - IAM Permissions)

**Not Yet Deployed**:
- Bedrock Agent resource
- Bedrock Guardrail
- Agent Action Groups
- Agent Alias

**Blocker**: AWS Lab user lacks permissions:
- `iam:CreateRole`
- `bedrock:CreateAgent`
- `bedrock:TagResource`

**Solution**: Deploy using `tf-provisioner` credentials

---

## Testing Summary

### Test 1: `get_recent_earthquakes` ✅

```bash
$ aws lambda invoke \
  --function-name groundsense-dev-get-recent-earthquakes \
  --cli-binary-format raw-in-base64-out \
  --payload '{"actionGroup": "RecentDataQueries", "function": "get_recent_earthquakes", "parameters": [{"name": "min_magnitude", "value": "4.0"}, {"name": "limit", "value": "10"}]}' \
  response.json

Result: SUCCESS - Retrieved 2 earthquakes (M5.1, M4.5)
```

**Output**:
```json
{
  "event_count": 2,
  "events": [
    {
      "earthquake_id": "us6000shar",
      "magnitude": 5.1,
      "place": "South Sandwich Islands region",
      "time": "2026-03-19T02:07:29.673000",
      "latitude": -59.3269,
      "longitude": -25.9885,
      "depth_km": 35.0
    },
    {
      "earthquake_id": "us6000sh9q",
      "magnitude": 4.5,
      "place": "54 km SSW of Maisí, Cuba",
      "time": "2026-03-18T22:07:55.816000",
      "latitude": 19.772,
      "longitude": -74.2937,
      "depth_km": 10.985
    }
  ]
}
```

### Test 2: `analyze_historical_patterns` ⚠️

```bash
$ aws lambda invoke \
  --function-name groundsense-dev-analyze-patterns \
  --cli-binary-format raw-in-base64-out \
  --payload '{"actionGroup": "HistoricalAnalytics", "function": "analyze_historical_patterns", "parameters": [{"name": "query_type", "value": "count"}, {"name": "time_range_days", "value": "365"}, {"name": "min_magnitude", "value": "3.0"}]}' \
  response.json

Result: BLOCKED - Glue table doesn't exist yet
```

**Error**:
```json
{
  "error": "Error analyzing historical patterns: Query FAILED: TABLE_NOT_FOUND: line 2:14: Table 'awsdatacatalog.groundsense_dev_seismic_data.earthquakes' does not exist"
}
```

**Resolution Path** (requires permissions):
1. Manually invoke `seismic-poller` to populate S3 data
2. Manually trigger Glue Crawler: `aws glue start-crawler --name groundsense-dev-seismic-crawler`
3. Wait 1-5 minutes for crawler completion
4. Retry test

---

## Files Modified (Athena Fix)

### Configuration Fix Applied (March 19, 2026)

**Issue**: Wrong S3 bucket configured for Athena output location

**Files Changed**:
1. `infra/phase3/terraform.tfvars` - Fixed bucket name (manual edit, gitignored)
2. `infra/phase3/variables.tf` - Added `s3_seismic_archive_bucket` variable
3. `infra/phase3/main.tf` - Passed new variable to agent_tools module
4. `infra/phase3/modules/agent_tools/variables.tf` - Added variable definition
5. `infra/phase3/modules/agent_tools/main.tf` - Enhanced IAM permissions

**Changes Summary**:
```diff
# terraform.tfvars
- s3_athena_output_bucket = "groundsense-dev-seismic-archive"  # WRONG
+ s3_athena_output_bucket = "groundsense-dev-athena-results"   # CORRECT
+ s3_seismic_archive_bucket = "groundsense-dev-seismic-archive" # NEW

# IAM Policy Enhanced
+ s3:GetBucketLocation
+ s3:ListBucket
+ s3:ListBucketMultipartUploads
+ s3:ListMultipartUploadParts
+ s3:AbortMultipartUpload
(Full Athena-required S3 permissions)
```

**Status**: Code fixed, pending `terraform apply` to update deployed Lambda

---

## Next Actions

### Immediate (Manual Steps)

1. **Verify Data Pipeline**:
   ```bash
   # Check if seismic-poller has written data
   aws s3 ls s3://groundsense-dev-seismic-archive/data/ --recursive
   
   # Check CloudWatch Logs for seismic-poller
   aws logs tail /aws/lambda/groundsense-dev-seismic-poller --follow
   ```

2. **Trigger Data Population** (if needed):
   ```bash
   # Manually invoke USGS ingestor
   aws lambda invoke \
     --function-name groundsense-dev-seismic-poller \
     --payload '{}' \
     /tmp/ingest-response.json
   ```

3. **Create Glue Table**:
   ```bash
   # Start Glue Crawler manually
   aws glue start-crawler --name groundsense-dev-seismic-crawler
   
   # Monitor crawler status
   aws glue get-crawler --name groundsense-dev-seismic-crawler \
     | jq '.Crawler.State'
   # Wait for: "READY"
   
   # Verify table created
   aws glue get-table \
     --database-name groundsense_dev_seismic_data \
     --name earthquakes
   ```

4. **Apply Terraform Fix**:
   ```bash
   cd infra/phase3
   terraform apply
   # This updates Lambda env vars + IAM permissions
   ```

5. **Retest Athena Lambda**:
   ```bash
   aws lambda invoke \
     --function-name groundsense-dev-analyze-patterns \
     --cli-binary-format raw-in-base64-out \
     --payload '{"actionGroup": "HistoricalAnalytics", ...}' \
     response.json
   ```

### Phase 3 Completion

Once data pipeline is verified:

1. Deploy Bedrock Agent using `tf-provisioner` credentials:
   ```bash
   cd infra/phase3
   # Configure tf-provisioner AWS credentials
   terraform apply
   ```

2. Test Agent end-to-end:
   ```bash
   aws bedrock-agent-runtime invoke-agent \
     --agent-id <AGENT_ID> \
     --agent-alias-id <ALIAS_ID> \
     --session-id test-$(date +%s) \
     --input-text "Show me recent earthquakes above magnitude 4.0"
   ```

---

## Permission Blockers

**AWS Lab User** (`5410lab02`) **lacks**:
- `lambda:InvokeFunction` (seismic-poller)
- `lambda:UpdateFunctionConfiguration`
- `lambda:UpdateFunctionCode`
- `glue:GetCrawler`, `glue:StartCrawler`
- `glue:GetDatabase`, `glue:GetTable`
- `iam:CreateRole`, `iam:GetRole`, `iam:PutRolePolicy`
- `bedrock:CreateAgent`, `bedrock:TagResource`
- `s3:ListBucket` (seismic-archive, athena-results)

**Workaround**: Use `tf-provisioner` AWS user for deployment operations

---

## Summary

**Phase 3 Status**: 40% Complete

- ✅ Lambda tool functions implemented
- ✅ Athena configuration bug fixed
- ⏳ Glue table creation pending (data pipeline dependency)
- 🚫 Bedrock Agent deployment blocked (IAM permissions)

**Blockers**:
1. Data pipeline needs to populate S3 before Athena queries work
2. AWS Lab permissions insufficient for full deployment

**Estimated Time to Completion**:
- With proper permissions: ~10 minutes (terraform apply + test)
- Waiting for scheduled jobs: Up to 24 hours (next Glue Crawler run)

---

**Last Updated**: March 19, 2026
