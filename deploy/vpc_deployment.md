# VPC Deployment Guide

## Overview

This guide covers deploying the VPC infrastructure added to GroundSense. All 8 Lambda functions now run in a private subnet with VPC endpoints for AWS service access.

## Architecture Summary

**Single-AZ VPC Configuration:**
- VPC: 10.0.0.0/16
- Public subnet: 10.0.1.0/24 (us-east-1a)
- Private subnet: 10.0.10.0/24 (us-east-1a)
- 1 NAT Gateway (cost-optimized)
- 3 VPC Endpoints: S3 (gateway, free), DynamoDB (gateway, free), Bedrock (interface, ~$7/month)

**Lambda Functions in VPC:**
1. seismic_poller
2. document_fetcher
3. alert
4. kb_sync
5. get_recent_earthquakes
6. analyze_historical_patterns
7. get_hazard_assessment
8. get_location_context
9. fetch_weather_at_epicenter
10. response_formatter

## Cost Impact

- **NAT Gateway**: $32.40/month
- **NAT data transfer**: ~$0.045/GB
- **Bedrock Interface Endpoints**: ~$7/month
- **S3/DynamoDB Gateway Endpoints**: FREE
- **Total**: ~$39-46/month additional cost

## Deployment Steps

### 1. Reinitialize Terraform (Root Stack)

```bash
cd /Users/harsh/Artifacts/groundsense/infra
terraform init -upgrade
```

This downloads the VPC module and updates dependencies.

### 2. Review the Plan

```bash
terraform plan
```

Expected changes:
- ~20+ new resources (VPC, subnets, NAT, endpoints, security group)
- ~10 modified resources (Lambda functions with vpc_config, IAM role attachments)

### 3. Apply Changes

```bash
terraform apply
```

**Deployment time**: ~8-12 minutes (NAT Gateway creation is slow)

### 4. Update Phase 3 (Agent Tools)

The Phase 3 stack also needs the VPC variables:

```bash
cd /Users/harsh/Artifacts/groundsense/infra/phase3

# Edit terraform.tfvars to add (get from root stack outputs):
# private_subnet_id        = "subnet-xxxxx"
# lambda_security_group_id = "sg-xxxxx"

terraform init -upgrade
terraform plan
terraform apply
```

### 5. Update Phase 4 (Response Formatter)

```bash
cd /Users/harsh/Artifacts/groundsense/infra/phase4

# Edit terraform.tfvars to add (get from root stack outputs):
# private_subnet_id        = "subnet-xxxxx"
# lambda_security_group_id = "sg-xxxxx"

terraform init -upgrade
terraform plan
terraform apply
```

## Testing

### 1. Verify VPC Resources

```bash
# From root infra directory
terraform output

# Should show vpc_id, private_subnet_id, lambda_security_group_id
```

### 2. Test Seismic Poller (Phase 1)

```bash
aws lambda invoke \
  --function-name groundsense-dev-seismic-poller \
  --payload '{}' \
  response.json

cat response.json
```

**Expected**: First invocation will be slower (10-30s) due to ENI attachment. Subsequent invocations should be fast.

### 3. Test Document Fetcher

```bash
aws lambda invoke \
  --function-name groundsense-dev-document-fetcher \
  --payload '{}' \
  response.json
```

### 4. Test Agent Tool Lambda

```bash
aws lambda invoke \
  --function-name groundsense-dev-get-recent-earthquakes \
  --payload '{"min_magnitude": 4.0, "limit": 10}' \
  response.json

cat response.json
```

### 5. Monitor CloudWatch Logs

```bash
aws logs tail /aws/lambda/groundsense-dev-seismic-poller --follow
```

Look for:
- No VPC timeout errors
- Successful connections to DynamoDB/S3 (via endpoints)
- Successful connections to external APIs (via NAT)

## Troubleshooting

### Issue: Lambda timeout on first invocation

**Cause**: ENI attachment takes time (cold start)

**Solution**: This is expected. Wait 10-30 seconds and retry. Subsequent invocations will be fast.

### Issue: Lambda cannot reach external APIs

**Cause**: NAT Gateway not properly configured or route table issue

**Check**:
```bash
# Verify NAT Gateway is active
aws ec2 describe-nat-gateways --filter "Name=tag:Name,Values=groundsense-dev-nat"

# Verify route table
aws ec2 describe-route-tables --filters "Name=tag:Name,Values=groundsense-dev-private-rt"
```

### Issue: Lambda cannot access S3/DynamoDB

**Cause**: VPC endpoint not working

**Check**:
```bash
# Verify endpoints
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=<vpc-id>"
```

### Issue: ENI quota exceeded

**Cause**: AWS account has low ENI limits

**Solution**:
```bash
# Check current quota
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-DF5E4CA3

# Request increase if needed
```

## Rollback Procedure

If you need to revert to non-VPC architecture:

### 1. Remove VPC Configuration from Lambdas

Edit the following files and remove the `vpc_config` blocks:
- `infra/modules/ingestors/main.tf`
- `infra/modules/triggers/main.tf`
- `infra/phase3/modules/agent_tools/main.tf`
- `infra/phase4/main.tf`

Also remove the VPC IAM policy attachments (`aws_iam_role_policy_attachment.*_vpc`).

### 2. Remove VPC Module

Edit `infra/main.tf` and remove:
- The `module "vpc"` block
- The `private_subnet_id` and `lambda_security_group_id` parameters from module calls

### 3. Apply Changes

```bash
# Root stack
cd /Users/harsh/Artifacts/groundsense/infra
terraform apply

# Wait ~10 minutes for ENIs to be released

# Phase 3
cd /Users/harsh/Artifacts/groundsense/infra/phase3
terraform apply

# Phase 4
cd /Users/harsh/Artifacts/groundsense/infra/phase4
terraform apply
```

### 4. Destroy VPC Resources

After all Lambda ENIs are released:

```bash
cd /Users/harsh/Artifacts/groundsense/infra
terraform destroy -target=module.vpc
```

## Notes

- **Cold starts**: First Lambda invocation in VPC takes 10-30 seconds longer. This is one-time per function instance.
- **High availability**: Single-AZ setup means us-east-1a outage affects all functions.
- **Costs**: Monitor AWS Cost Explorer for NAT Gateway data transfer charges.
- **No code changes**: Lambda function code is unchanged - only infrastructure configuration.

## Next Steps

After successful deployment:

1. Monitor CloudWatch metrics for cold start times
2. Check AWS Cost Explorer after 24-48 hours to see actual NAT Gateway costs
3. Test all agent functionality through the UI
4. Consider adding CloudWatch alarms for VPC Lambda failures
