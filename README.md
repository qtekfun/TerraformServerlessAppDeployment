# Terraform Serverless App Deployment

## Architecture

A serverless AWS application that accepts POST requests containing text, tracks per-word frequency in DynamoDB, stores a top-10 report in S3, and returns a presigned URL to download it.

```
     ┌────┐          ┌───────────────┐          ┌──────────┐                        ┌─────────────┐          ┌─────────────┐
     │User│          │AWS API Gateway│          │AWS Lambda│                        │AWS Dynamo DB│          │AWS S3 Bucket│
     └─┬──┘          └───────┬───────┘          └────┬─────┘                        └──────┬──────┘          └──────┬──────┘
       │ "POST Request(Text)"│                       │                                     │                        │
       │ ────────────────────>                       │                                     │                        │
       │                     │                       │                                     │                        │
       │                     │        "Event"        │                                     │                        │
       │                     │ ──────────────────────>                                     │                        │
       │                     │                       │                                     │                        │
       │                     │                       │     "Atomic upsert per word"        │                        │
       │                     │                       │ ───────────────────────────────────>│                        │
       │                     │                       │                                     │                        │
       │                     │                       │        "Paginated scan"             │                        │
       │                     │                       │ ───────────────────────────────────>│                        │
       │                     │                       │                                     │                        │
       │                     │                       │           "All items"               │                        │
       │                     │                       │ <───────────────────────────────────│                        │
       │                     │                       │                                     │                        │
       │                     │                       │────┐                                │                        │
       │                     │                       │    │ "Sort and filter top-10"       │                        │
       │                     │                       │<───┘                                │                        │
       │                     │                       │                                     │                        │
       │                     │                       │                      "Upload JSON report"                    │
       │                     │                       │ ────────────────────────────────────────────────────────────>│
       │                     │                       │                                     │                        │
       │                     │                       │                     "Generate presigned URL"                 │
       │                     │                       │ ────────────────────────────────────────────────────────────>│
       │                     │                       │                                     │                        │
       │                     │                       │                       "presigned URL"                        │
       │                     │                       │ <────────────────────────────────────────────────────────────│
       │                     │                       │                                     │                        │
       │             {"url": "presigned URL"}        │                                     │                        │
       │ <────────────────────────────────────────────                                     │                        │
     ┌─┴──┐          ┌───────┴───────┐          ┌────┴─────┐                        ┌──────┴──────┐          ┌──────┴──────┐
     │User│          │AWS API Gateway│          │AWS Lambda│                        │AWS Dynamo DB│          │AWS S3 Bucket│
     └────┘          └───────────────┘          └──────────┘                        └─────────────┘          └─────────────┘
```

### Infrastructure highlights

- **API Gateway v2** — HTTP API with a single `POST /` route
- **Lambda** (Python 3.12) — tokenizes input text into individual words; uses an atomic DynamoDB `ADD` upsert to eliminate race conditions and halve round-trips; handles paginated DynamoDB scans
- **DynamoDB** — on-demand (`PAY_PER_REQUEST`) billing, encryption at rest enabled
- **S3** — all public access blocked, AES-256 server-side encryption; presigned URL expiry configurable (default 10 min)
- **CloudWatch alarms** — Lambda errors, Lambda p95 duration > 5 s, DynamoDB throttles; optional SNS email notifications

---

## Prerequisites

1. An AWS account (free tier is sufficient for testing)
2. AWS credentials exported in your shell:
   ```bash
   export AWS_ACCESS_KEY_ID=<your-key-id>
   export AWS_SECRET_ACCESS_KEY=<your-secret-key>
   export AWS_DEFAULT_REGION=eu-west-3   # or any region you prefer
   ```
3. [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5

---

## Deploy

```bash
terraform init
terraform plan
terraform apply        # confirm with "yes" when prompted
```

### Optional variables

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `eu-west-3` | AWS region for all resources |
| `presigned_url_expiry` | `600` | Presigned URL TTL in seconds |
| `log_retention_days` | `365` | CloudWatch log retention in days |
| `alert_email` | `""` | Email for CloudWatch + cost anomaly alerts (leave empty to disable) |
| `monthly_cost_budget_usd` | `"10"` | Monthly cost budget threshold in USD |
| `api_key` | `""` | API key for `x-api-key` header auth (leave empty for public endpoint) |
| `enable_s3_versioning` | `false` | Enable S3 versioning on the reports bucket |

Example with all optional features:

```bash
terraform apply \
  -var="alert_email=you@example.com" \
  -var="monthly_cost_budget_usd=5" \
  -var="api_key=my-secret-key" \
  -var="enable_s3_versioning=true"
```

### Authenticated requests

When `api_key` is set, every request must include the `x-api-key` header:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "x-api-key: my-secret-key" \
  -d '{"parameter": "hello world"}' \
  $(terraform output -raw public_uri)
```

---

## Usage

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"parameter": "the quick brown fox jumps over the lazy dog"}' \
  $(terraform output -raw public_uri)
```

The response is a JSON object with a presigned URL:

```json
{"url": "https://app-serverless-s3-bucket.s3.amazonaws.com/top.json?..."}
```

Open the URL to download the top-10 word frequency report:

```json
{
  "top10words": [
    {"word": "the", "times": 2},
    {"word": "quick", "times": 1},
    ...
  ]
}
```

---

## Running tests

Unit tests require no AWS credentials and no external dependencies beyond the Python standard library:

```bash
cd app
python -m unittest discover -s tests -v
```

---

## Remote state (team use)

Run the bootstrap once to create the S3 + DynamoDB backend, then migrate:

```bash
cd bootstrap
terraform init
terraform apply -var="state_bucket_name=<globally-unique-bucket-name>"

# Back in the repo root:
cp backend.tf.example backend.tf
# Edit backend.tf — replace <state_bucket_name> with the output value
terraform init   # Terraform will offer to migrate local state to S3
```

## Canary deployments

The Lambda function publishes a new immutable version on every `terraform apply`. Traffic is served via the `live` alias. To do a staged rollout before fully cutting over, update the alias routing config:

```hcl
# In modules/aws/lambda.tf — temporarily add routing_config to the alias:
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.serverless_app.function_name
  function_version = aws_lambda_function.serverless_app.version   # new version

  routing_config {
    additional_version_weights = {
      "<previous_version_number>" = 0.9   # 90% to old, 10% to new
    }
  }
}
```

Once confident, remove `routing_config` and `terraform apply` to send 100% of traffic to the new version.

---

## Tear down

```bash
terraform destroy
```

---

## Pending points to be production ready

* [x] Basic app
* [x] Word tokenization — input text split into individual words (not treated as a single token)
* [x] Atomic DynamoDB counter — single `ADD` upsert replaces race-prone get-then-put
* [x] DynamoDB pagination — full table scan handles tables larger than 1 MB
* [x] S3 encryption at rest — AES-256 SSE enabled
* [x] S3 public access fully blocked — presigned URLs are used instead
* [x] DynamoDB on-demand billing — no more throttling at fixed 5 RCU/WCU
* [x] Configure monitoring — CloudWatch alarms for Lambda errors, duration, and DynamoDB throttles
* [x] Configure alerting for malfunctions — optional SNS email via `alert_email` variable
* [x] Input validation — empty, whitespace-only, and >10 000-character inputs rejected with HTTP 400
* [x] Configurable presigned URL expiry — via `presigned_url_expiry` Terraform variable
* [x] Unit tests — 12 tests covering all Lambda handlers and helpers
* [x] Configure alerting for costs — AWS Budgets (80%/100% thresholds) + Cost Anomaly Detection via `monthly_cost_budget_usd` and `alert_email`
* [x] Canary / staged deployments — Lambda publishes versions on every deploy; `live` alias enables weighted routing via `routing_config`
* [x] S3 versioning — opt-in via `enable_s3_versioning = true`
* [x] Authentication — optional Lambda REQUEST authorizer validating `x-api-key` header; enabled by setting `api_key`
* [x] Terraform remote state — `bootstrap/` provisions S3 + DynamoDB backend; `backend.tf.example` documents migration steps
