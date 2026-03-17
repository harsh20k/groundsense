# Phase 1 Deployment Guide

This guide walks through deploying the GroundSense Phase 1 Data Pipeline infrastructure to AWS.

## Prerequisites

### Required Software
- **Terraform** >= 1.5 ([Download](https://www.terraform.io/downloads))
- **AWS CLI** >= 2.0 ([Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **Python** 3.11 (for local Lambda testing)

### AWS Account Setup

1. **AWS Account**: You need an AWS account with appropriate permissions
2. **AWS CLI Configuration**: Configure your AWS credentials

```bash
aws configure
```

Enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `us-east-1`
- Default output format: `json`

3. **Verify AWS Access**:

```bash
aws sts get-caller-identity
```

### Required IAM Permissions

Permissions are managed via the `iam` Terraform module (`infra/modules/iam/`). It creates a custom managed policy (`groundsense-<env>-projectowner-policy`) and attaches it to the IAM user **`groundsense-projectowner`**.

The policy grants scoped access (limited to `groundsense-<env>-*` resources) for:
- Lambda (create, update, delete functions; add permissions)
- DynamoDB (create, update, delete tables)
- S3 (create buckets, configure notifications, lifecycle, object access)
- EventBridge Scheduler (create, update, delete schedules)
- SNS (create topics, manage subscriptions)
- Glue (create databases, crawlers; start/stop crawlers)
- Athena (create, update, delete workgroups)
- IAM (create roles and policies for Lambda execution)
- CloudWatch Logs (create log groups, set retention)

**Prerequisites**: The IAM user `groundsense-projectowner` must already exist before running `terraform apply`. The module attaches permissions to the existing user — it does not create the user.

To create the user if it doesn't exist yet:
```bash
aws iam create-user --user-name groundsense-projectowner
```

Then configure your AWS CLI with that user's credentials before deploying.

## Deployment Steps

### 1. Clone and Navigate to Infrastructure Directory

```bash
cd /Users/harsh/Artifacts/groundsense/infra
```

### 2. Configure Variables

Create your `terraform.tfvars` file from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your preferred settings:

```hcl
# AWS Configuration
aws_region = "us-east-1"

# Project Configuration
project_name = "groundsense"
environment  = "dev"

# DynamoDB Configuration
dynamodb_ttl_days = 30

# Alert Configuration
alert_email = "vn328490@dal.ca"  # Change to your email
```

**Important**: Update `alert_email` to your actual email address to receive earthquake alerts.

### 3. Initialize Terraform

```bash
terraform init
```

This will:
- Download required providers (AWS, Archive)
- Initialize backend
- Prepare modules

Expected output:
```
Terraform has been successfully initialized!
```

### 4. Review the Deployment Plan

```bash
terraform plan
```

This shows what will be created:
- 4 Lambda functions (seismic_poller, document_fetcher, alert, kb_sync)
- 1 DynamoDB table (earthquakes)
- 3 S3 buckets (seismic-archive, documents, athena-results)
- 2 EventBridge Scheduler rules
- 1 SNS topic + email subscription
- 1 Glue database + crawler
- 1 Athena workgroup
- IAM roles, policies, and 1 user policy attachment (`groundsense-projectowner`)
- CloudWatch log groups

Review the output carefully. Expected resource count: ~42 resources.

### 5. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm.

Deployment takes approximately 2-3 minutes.

### 6. Confirm SNS Email Subscription

After deployment completes:

1. Check your email inbox for `vn328490@dal.ca`
2. Look for "AWS Notification - Subscription Confirmation"
3. Click the confirmation link

**Important**: Alerts won't be delivered until you confirm the subscription.

### 7. Verify Deployment

#### Check Terraform Outputs

```bash
terraform output
```

You should see:
```
alert_lambda_function_name = "groundsense-dev-alert"
athena_workgroup_name = "groundsense-dev-seismic-analysis"
documents_bucket_name = "groundsense-dev-documents"
document_fetcher_function_name = "groundsense-dev-document-fetcher"
dynamodb_table_name = "groundsense-dev-earthquakes"
glue_database_name = "groundsense_dev_seismic_data"
kb_sync_lambda_function_name = "groundsense-dev-kb-sync"
seismic_archive_bucket_name = "groundsense-dev-seismic-archive"
seismic_poller_function_name = "groundsense-dev-seismic-poller"
sns_topic_arn = "arn:aws:sns:us-east-1:XXXX:groundsense-dev-earthquake-alerts"
```

#### Verify AWS Resources

**Lambda Functions**:
```bash
aws lambda list-functions --query 'Functions[?contains(FunctionName, `groundsense`)].FunctionName'
```

**DynamoDB Table**:
```bash
aws dynamodb describe-table --table-name groundsense-dev-earthquakes
```

**S3 Buckets**:
```bash
aws s3 ls | grep groundsense
```

**EventBridge Schedules**:
```bash
aws scheduler list-schedules --query 'Schedules[?contains(Name, `groundsense`)]'
```

## Testing the Data Pipeline

### 1. Manually Trigger Seismic Poller

```bash
aws lambda invoke \
  --function-name groundsense-dev-seismic-poller \
  --payload '{}' \
  /tmp/seismic-poller-response.json

cat /tmp/seismic-poller-response.json
```

Expected response:
```json
{
  "statusCode": 200,
  "body": "{\"message\": \"Seismic data poll completed\", \"nrcan_events\": X, \"usgs_events\": Y}"
}
```

### 2. Check Lambda Logs

```bash
aws logs tail /aws/lambda/groundsense-dev-seismic-poller --follow
```

Look for:
- "Fetched X events from NRCan"
- "Fetched Y events from USGS"
- "Stored event ... in DynamoDB"
- "Stored event ... in S3"

### 3. Verify DynamoDB Data

```bash
aws dynamodb scan \
  --table-name groundsense-dev-earthquakes \
  --max-items 5
```

You should see earthquake records with fields:
- `earthquake_id`
- `magnitude`
- `place`
- `time`
- `longitude`, `latitude`, `depth_km`
- `expires_at` (TTL timestamp)

### 4. Check S3 Data

```bash
# List seismic events in S3
aws s3 ls s3://groundsense-dev-seismic-archive/data/ --recursive | head -10

# Download a sample event
aws s3 cp s3://groundsense-dev-seismic-archive/data/2026/03/17/[event-id].json /tmp/sample-event.json
cat /tmp/sample-event.json | jq .
```

### 5. Test Document Fetcher (Stub)

```bash
aws lambda invoke \
  --function-name groundsense-dev-document-fetcher \
  --payload '{}' \
  /tmp/document-fetcher-response.json

cat /tmp/document-fetcher-response.json
```

Check documents bucket:
```bash
aws s3 ls s3://groundsense-dev-documents/ --recursive
```

### 6. Test Alert Lambda (Stub)

Create a test M5.0+ event in the alerts/ prefix to trigger the Lambda:

```bash
# Create a test alert event
cat > /tmp/test-alert.json << 'EOF'
{
  "id": "test-event-001",
  "type": "Feature",
  "properties": {
    "mag": 5.5,
    "place": "Test Location, CA",
    "time": 1710691200000,
    "url": "https://example.com/test"
  },
  "geometry": {
    "type": "Point",
    "coordinates": [-122.4, 37.8, 10.0]
  }
}
EOF

# Upload to alerts/ prefix
aws s3 cp /tmp/test-alert.json s3://groundsense-dev-seismic-archive/alerts/2026/03/17/test-event-001.json
```

Check alert Lambda logs:
```bash
aws logs tail /aws/lambda/groundsense-dev-alert --follow
```

You should see the alert processing (stub logs only in Phase 1).

### 7. Verify Glue Crawler

The Glue Crawler runs daily at 3 AM UTC. To run it manually:

```bash
aws glue start-crawler --name groundsense-dev-seismic-crawler
```

Wait 2-3 minutes, then check status:

```bash
aws glue get-crawler --name groundsense-dev-seismic-crawler | jq '.Crawler.State'
```

### 8. Query Data with Athena

After the Glue Crawler completes:

1. Navigate to AWS Athena Console
2. Select workgroup: `groundsense-dev-seismic-analysis`
3. Run a query:

```sql
-- Show all tables
SHOW TABLES IN groundsense_dev_seismic_data;

-- Query recent earthquakes
SELECT 
  properties.mag as magnitude,
  properties.place as location,
  properties.time as event_time,
  geometry.coordinates[0] as longitude,
  geometry.coordinates[1] as latitude
FROM groundsense_dev_seismic_data.data
WHERE year = 2026 AND month = 3
ORDER BY properties.time DESC
LIMIT 10;
```

## Monitoring

### CloudWatch Dashboards

View Lambda execution metrics:

```bash
# Seismic poller invocations
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=groundsense-dev-seismic-poller \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### Cost Monitoring

Check AWS Cost Explorer for Phase 1 costs:
- Lambda invocations: ~43,200/month (1 per minute)
- DynamoDB writes: Depends on earthquake frequency
- S3 storage: Minimal (~1-10 MB/day)
- Athena queries: Pay per TB scanned

Expected monthly cost: **$0.10 - $0.50**

## Troubleshooting

### Issue: Lambda Functions Not Being Triggered

**Symptoms**: No logs in CloudWatch after deployment

**Solution**: Check EventBridge Scheduler:
```bash
aws scheduler get-schedule --name groundsense-dev-seismic-poller
```

Verify IAM role has `lambda:InvokeFunction` permission.

### Issue: S3 Event Notifications Not Working

**Symptoms**: Alert/KB sync Lambdas not triggered when files uploaded

**Solution**: 
1. Verify S3 bucket notifications:
```bash
aws s3api get-bucket-notification-configuration \
  --bucket groundsense-dev-seismic-archive
```

2. Check Lambda permissions for S3 invocation:
```bash
aws lambda get-policy \
  --function-name groundsense-dev-alert
```

### Issue: DynamoDB ConditionalCheckFailedException

**Symptoms**: Duplicate earthquake IDs causing errors

**Solution**: This is expected behavior (deduplication). Check logs to confirm:
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/groundsense-dev-seismic-poller \
  --filter-pattern "already exists"
```

### Issue: Terraform State Conflicts

**Symptoms**: "state lock" errors during apply

**Solution**: 
```bash
# List locks (if using DynamoDB backend)
terraform force-unlock [LOCK_ID]

# Or wait 15 minutes for automatic unlock
```

### Issue: API Rate Limiting from NRCan/USGS

**Symptoms**: Lambda errors with HTTP 429

**Solution**: 
- NRCan/USGS have generous rate limits for personal use
- Add exponential backoff in Lambda code
- Reduce polling frequency if needed

## Updating the Infrastructure

### Modify Lambda Code

1. Edit Lambda handler in `lambda/*/handler.py`
2. Apply changes:

```bash
cd infra
terraform apply
```

Terraform will detect changes in the source directory and rebuild Lambda zips.

### Modify Infrastructure

1. Edit Terraform files in `infra/` or `infra/modules/`
2. Plan changes:

```bash
terraform plan
```

3. Apply:

```bash
terraform apply
```

### Update Variables

1. Edit `terraform.tfvars`
2. Apply:

```bash
terraform apply
```

## Destroying the Infrastructure

**Warning**: This will delete all data and resources.

```bash
cd infra
terraform destroy
```

Type `yes` to confirm.

**Note**: S3 buckets with objects may fail to delete. Empty them first:

```bash
aws s3 rm s3://groundsense-dev-seismic-archive --recursive
aws s3 rm s3://groundsense-dev-documents --recursive
aws s3 rm s3://groundsense-dev-athena-results --recursive

# Then retry destroy
terraform destroy
```

## Next Steps

After Phase 1 is deployed and tested:

1. **Phase 2**: Create Bedrock Knowledge Base for document RAG
2. **Phase 3**: Implement Bedrock Agent with 5 Lambda tools
3. **Phase 4**: Build response formatter for frontend
4. **Phase 5**: Deploy web UI with visualizations
5. **Phase 6**: Wire up proactive alerts to agent
6. **Phase 7**: Add monitoring, X-Ray tracing, documentation

## Support

### Useful AWS Documentation
- [Lambda Developer Guide](https://docs.aws.amazon.com/lambda/)
- [DynamoDB TTL](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html)
- [S3 Event Notifications](https://docs.aws.amazon.com/AmazonS3/latest/userguide/NotificationHowTo.html)
- [EventBridge Scheduler](https://docs.aws.amazon.com/scheduler/latest/UserGuide/)
- [Glue Crawler](https://docs.aws.amazon.com/glue/latest/dg/add-crawler.html)
- [Athena SQL Reference](https://docs.aws.amazon.com/athena/latest/ug/ddl-sql-reference.html)

### Debug Commands Cheat Sheet

```bash
# View all Lambda functions
aws lambda list-functions --query 'Functions[?contains(FunctionName, `groundsense`)].FunctionName'

# Tail Lambda logs
aws logs tail /aws/lambda/groundsense-dev-seismic-poller --follow

# Scan DynamoDB
aws dynamodb scan --table-name groundsense-dev-earthquakes --max-items 10

# List S3 objects
aws s3 ls s3://groundsense-dev-seismic-archive/data/ --recursive | head -20

# Check Glue Crawler status
aws glue get-crawler --name groundsense-dev-seismic-crawler

# View SNS subscriptions
aws sns list-subscriptions-by-topic --topic-arn $(terraform output -raw sns_topic_arn)

# Get Terraform outputs
terraform output
```

---

**Deployment Complete!** 🎉

Your Phase 1 Data Pipeline is now running and collecting earthquake data every minute.
