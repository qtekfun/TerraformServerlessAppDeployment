# lambda_function.py

import json, tempfile, boto3, os, logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Retrieve environment variables
s3_bucket_name = os.environ['S3_BUCKET_NAME']
dynamodb_table_name = os.environ['DYNAMODB_TABLE']

def lambda_handler(event, context):

    logging.info(f"Received event: {json.dumps(event)}")

      
    # s3_url = upload_to_s3()

    # Extract the parameter from the incoming JSON request
    try:
        request_body = json.loads(event['body'])
        parameter_value = request_body.get('parameter', 'unknown')
    except json.JSONDecodeError:
        parameter_value = 'unknown'

    insert_ddbb(parameter_value)

    # Construct the response body including the parameter value
    response_body = f"Hello, I'm fine. Your env vars are {s3_bucket_name}.\n"
    response_body += f"The parameter you sent me was {parameter_value}\n"
    response_body += f"event is {event}\n"
    # response_body += f"{s3_url}"

    # Return the response with a 200 status code
    return {
        'statusCode': 200,
        'body': response_body
    }

def insert_ddbb(word):
    dynamodb = boto3.client('dynamodb')
    print(f'get table')
    print(f'table name is {dynamodb_table_name}')
    print(f'word is {word}')
    data = {"word" : {'S': word},
            "times": {'N': '1'}}
    existing_item = dynamodb.get_item(TableName=dynamodb_table_name, 
                                      Key={'word': {'S': word}})
    print(f'existing_item is {existing_item}')
    if existing_item:
        dynamodb.update_item(
            TableName=dynamodb_table_name,
            Key={'word': {'S': word}},
            UpdateExpression='SET times = times + :inc',
            ExpressionAttributeValues={':inc': {'N': '1'}}
        )
    else:
        dynamodb.put_item(TableName=dynamodb_table_name, Item=data)

def upload_to_s3():

    data = {"key": "value"}

    print(f'data is {data}')

    s3 = boto3.client('s3')

    print(f's3 client')

    s3_key = 'top.json'

    print(f's3 key is {s3_key}')

    s3.put_object(Body=data, Bucket=s3_bucket_name, Key=s3_key)

    print(f'file uploaded')

    return ""
