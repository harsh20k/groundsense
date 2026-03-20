# Athena Configuration Fix - Deployment Instructions

## Issue Discovered

The `analyze_historical_patterns` Lambda was failing with:
```
Error: Unable to verify/create output bucket groundsense-dev-athena-results
```

## Root Cause

**Configuration Error in `terraform.tfvars`**:
- Variable `s3_athena_output_bucket` was set to `groundsense-dev-seismic-archive` (data lake bucket)
- Should be `groundsense-dev-athena-results` (dedicated Athena output bucket)

**IAM Permission Scope Issue**:
- Permissions were only granted to `s3://groundsense-dev-athena-results/athena-results/*`
- Athena requires bucket-level permissions (GetBucketLocation, ListBucket)

## Files Fixed

All changes are in `infra/phase3/`:

1. **terraform.tfvars** (gitignored - manual update required)
   ```hcl
   s3_athena_output_bucket      = "groundsense-dev-athena-results"  # Fixed
   s3_seismic_archive_bucket    = "groundsense-dev-seismic-archive" # Added
   ```
   
   **Note**: This file is in `.gitignore` for security. When deploying, manually update:
   - Line 12: Change `s3_athena_output_bucket` value
   - Line 13: Add `s3_seismic_archive_bucket` line

2. **variables.tf**
   - Added new variable: `s3_seismic_archive_bucket`

3. **main.tf**
   - Passed `s3_seismic_archive_bucket` to agent_tools module

4. **modules/agent_tools/variables.tf**
   - Added `s3_seismic_archive_bucket` variable definition

5. **modules/agent_tools/main.tf**
   - Enhanced IAM policy for `analyze_historical_patterns` Lambda:
     ```json
     {
       "Sid": "S3AthenaResults",
       "Effect": "Allow",
       "Action": [
         "s3:GetBucketLocation",
         "s3:GetObject",
         "s3:ListBucket",
         "s3:ListBucketMultipartUploads",
         "s3:ListMultipartUploadParts",
         "s3:AbortMultipartUpload",
         "s3:PutObject"
       ],
       "Resource": [
         "arn:aws:s3:::groundsense-dev-athena-results",
         "arn:aws:s3:::groundsense-dev-athena-results/*"
       ]
     }
     ```
   - Separated S3 permissions:
     - **Athena Results Bucket**: Full write access for query outputs
     - **Seismic Archive Bucket**: Read-only for data lake queries

## How to Deploy the Fix

### Prerequisites
- AWS credentials with permissions for:
  - `lambda:UpdateFunctionConfiguration`
  - `iam:PutRolePolicy`
  - `iam:GetRole`

### Deployment Steps

```bash
# Navigate to phase3 directory
cd /Users/harsh/Artifacts/groundsense/infra/phase3

# Review changes
terraform plan

# Expected changes:
# - Update Lambda environment variables (S3_ATHENA_OUTPUT_BUCKET)
# - Update IAM role policy for groundsense-dev-analyze-patterns

# Apply fixes
terraform apply

# Verify Lambda configuration
aws lambda get-function-configuration \
  --function-name groundsense-dev-analyze-patterns \
  --query 'Environment.Variables'

# Expected output:
# {
#   "ATHENA_WORKGROUP_NAME": "groundsense-dev-seismic-analysis",
#   "GLUE_DATABASE_NAME": "groundsense_dev_seismic_data",
#   "S3_ATHENA_OUTPUT_BUCKET": "groundsense-dev-athena-results"
# }
```

## Testing After Fix

```bash
# Test Lambda directly
aws lambda invoke \
  --function-name groundsense-dev-analyze-patterns \
  --cli-binary-format raw-in-base64-out \
  --payload '{
    "actionGroup": "HistoricalAnalytics",
    "function": "analyze_historical_patterns",
    "parameters": [
      {"name": "query_type", "value": "count"},
      {"name": "time_range_days", "value": "365"},
      {"name": "min_magnitude", "value": "3.0"}
    ]
  }' \
  response.json

cat response.json | jq .
```

**Expected Success Response**:
```json
{
  "response": {
    "actionGroup": "HistoricalAnalytics",
    "function": "analyze_historical_patterns",
    "functionResponse": {
      "responseBody": {
        "TEXT": {
          "body": "{\"query_parameters\": {...}, \"results\": {...}}"
        }
      }
    }
  }
}
```

## AWS Lab Environment Note

If deploying in AWS Academy Lab:
- Use `tf-provisioner` user credentials (same as Phase 2)
- Standard lab user (`5410lab02`) lacks IAM/Lambda update permissions
- Configure AWS CLI with provisioner credentials before running `terraform apply`

## Verification Checklist

- [ ] `terraform plan` shows updates to Lambda env vars and IAM policy
- [ ] `terraform apply` completes without errors
- [ ] Lambda environment variable shows correct bucket name
- [ ] Direct Lambda invocation succeeds (no bucket error)
- [ ] Athena query completes and returns data
- [ ] Results written to `s3://groundsense-dev-athena-results/`

---

**Status**: Fix implemented in code. Ready for `terraform apply` with appropriate AWS permissions.

**Date**: March 19, 2026
