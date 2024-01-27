# Serverless App

## Usage

In order to use it:

``` bash
curl -X POST -H "Content-Type: application/json" -d '{"parameter": "hola"}' $(terraform output -raw api_gateway_uri)
```