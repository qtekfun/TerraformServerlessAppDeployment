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
| `log_retention_days` | `30` | CloudWatch log retention |
| `alert_email` | `""` | Email for alarm notifications (leave empty to disable) |

Example with alert email:

```bash
terraform apply -var="alert_email=you@example.com"
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
* [ ] Configure alerting for costs — set up AWS Budgets or Cost Anomaly Detection in the console
* [ ] Canary / staged deployments — evaluate AWS Lambda aliases + weighted routing on API Gateway
* [ ] S3 versioning — evaluate if point-in-time recovery of reports is needed
* [ ] Authentication — add an API key or JWT authorizer to the API Gateway route
* [ ] Terraform remote state — store state in S3 + DynamoDB lock for team use
