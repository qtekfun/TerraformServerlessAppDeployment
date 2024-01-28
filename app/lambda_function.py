# lambda_function.py

import json, tempfile, boto3, os, logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Retrieve environment variables
s3_bucket_name = os.environ['S3_BUCKET_NAME']
dynamodb_table_name = os.environ['DYNAMODB_TABLE']

def lambda_handler(event, context):

    logging.info(f"Received event: {json.dumps(event)}")

    # Extract the parameter from the incoming JSON request
    try:
        request_body = json.loads(event['body'])
        parameter_value = request_body.get('parameter', 'unknown')
    except json.JSONDecodeError:
        parameter_value = 'unknown'

    # Return 201 if no parameter received
    if parameter_value == 'unknown':
        return {'statuscode': 201,
                'body': 'Missing parameter in body'}

    # Insert in dynamodb the parameter
    insert_ddbb(parameter_value)

    # Get the top 10 most common words
    top10 = get_top_10()

    # fileName = create_temp_file(top10)
    response = upload_to_s3(top10)
    
    # Return the response with a 200 status code
    return {
        'statusCode': 200,
        'body': response
    }

def insert_ddbb(word):
    dynamodb = boto3.client('dynamodb')
    data = {"word" : {'S': word},
            "times": {'N': '1'}}
    
    # Check if the word already exists
    existing_item = dynamodb.get_item(TableName=dynamodb_table_name, 
                                      Key={'word': {'S': word}}).get('Item')

    if existing_item:
        # If exists, update counter
        dynamodb.update_item(
            TableName=dynamodb_table_name,
            Key={'word': {'S': word}},
            UpdateExpression='SET times = times + :inc',
            ExpressionAttributeValues={':inc': {'N': '1'}}
        )
    else:
        # Include the new word
        dynamodb.put_item(TableName=dynamodb_table_name, Item=data)

def get_top_10():
    dynamodb = boto3.client('dynamodb')
    response = dynamodb.scan(TableName=dynamodb_table_name)
    items = response.get('Items', [])
    items_sorted = sorted(items, key=lambda x: int(x['times']['N']), reverse=True)
    top_10_elements = items_sorted[:10]
    combined_json = {'top10words': top_10_elements} 
    return combined_json

def create_temp_file(json_content):
    temp_file = tempfile.NamedTemporaryFile(delete=False)
    with open(temp_file.name, 'w') as file:
        json.dump(json_content, file)
    return temp_file.name

def upload_to_s3(text):
    file_name = "top.json"
    lambda_path = "/tmp/" + file_name
    with open(lambda_path, 'w') as f:
        json.dump(text, f)
    s3 = boto3.resource("s3")
    s3.meta.client.upload_file(lambda_path, s3_bucket_name, file_name)

    try:
        response = s3.meta.client.generate_presigned_url('get_object',
                                            Params={'Bucket': s3_bucket_name,
                                                    'Key': file_name},
                                            ExpiresIn=600)
    except ClientError as e:
        logging.error(e)
        return None

    return response