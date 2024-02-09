# Serverless App

## Architecture

The requirement was:
* Create a serverless app: this is why I used serverless services from AWS
* User make a post Request to the app public endpoint like:
``` bash
curl -X POST -H "Content-Type: application/json" -d '{"parameter": "hola"}' $(terraform output -raw api_gateway_uri)
```
* The app store in a json file the top 10 most frequent received words stored in AWS Dynamo DB and create a Json file stored in an AWS S3 Bucket
* Return to the user the url for download JSON file from S3.

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
       │                     │                       │        "Insert/Update word"         │                        │       
       │                     │                       │ ───────────────────────────────────>│                        │       
       │                     │                       │                                     │                        │       
       │                     │                       │        "Query Element list"         │                        │       
       │                     │                       │ ───────────────────────────────────>│                        │       
       │                     │                       │                                     │                        │       
       │                     │                       │           "Element list"            │                        │       
       │                     │                       │ <───────────────────────────────────│                        │       
       │                     │                       │                                     │                        │       
       │                     │                       │────┐                                │                        │       
       │                     │                       │    │ "Short and Filter Element List"│                        │       
       │                     │                       │<───┘                                │                        │       
       │                     │                       │                                     │                        │       
       │                     │                       │                      "Create JSON file"                      │       
       │                     │                       │ ────────────────────────────────────────────────────────────>│       
       │                     │                       │                                     │                        │       
       │                     │                       │                     "Get presigned URL"                      │       
       │                     │                       │ ────────────────────────────────────────────────────────────>│       
       │                     │                       │                                     │                        │       
       │                     │                       │                       "presigned URL"                        │       
       │                     │                       │ <────────────────────────────────────────────────────────────│       
       │                     │                       │                                     │                        │       
       │               "presigned URL"               │                                     │                        │       
       │ <────────────────────────────────────────────                                     │                        │       
     ┌─┴──┐          ┌───────┴───────┐          ┌────┴─────┐                        ┌──────┴──────┐          ┌──────┴──────┐
     │User│          │AWS API Gateway│          │AWS Lambda│                        │AWS Dynamo DB│          │AWS S3 Bucket│
     └────┘          └───────────────┘          └──────────┘                        └─────────────┘          └─────────────┘
```

## Deploy POC

To test this app you will need to follow this steps:

1. Prerequisites:
    1. Get an AWS account (a free tier should be good enough)
    1. Get your AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.
    1. Install [Terraform](https://developer.hashicorp.com/terraform/install)
1. Execute `terraform init` to initialize the project
1. Execute `terraform plan` to see an overview on what is going to do Terraform
1. Ececute `terraform apply` to deploy the infrastructure. It will request your confirmation. Answer yes when promted.

## Usage

Just make a curl request to the uri provided by terraform apply. For example:

``` bash
curl -X POST -H "Content-Type: application/json" -d '{"parameter": "hola"}' $(terraform output -raw public_uri)
```

In that command, the uri is directly got from the output of terraform apply and as an example "hola" is used as a parameter.

## Pending points to be production ready

* [x] Basic app
* [ ] Configure the credentials in a safe way
* [ ] Configure Monitoring
* [ ] Configure Alerting Malfunctions or thresholds
* [ ] Configure Alerting Costs
* [ ] Preparing QA tests for the app
* [ ] Evaluate S3 versioning if needed
* [ ] Check if AWS API Gateway can deploy Canary deployments without performance disruption
