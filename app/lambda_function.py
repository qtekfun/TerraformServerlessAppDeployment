# lambda_function.py

import json, re, boto3, os, logging
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Retrieve environment variables
s3_bucket_name = os.environ['S3_BUCKET_NAME']
dynamodb_table_name = os.environ['DYNAMODB_TABLE']
presigned_url_expiry = int(os.environ.get('PRESIGNED_URL_EXPIRY', '600'))

def lambda_handler(event, context):

    logging.info(f"Received event: {json.dumps(event)}")

    # Extract the parameter from the incoming JSON request
    try:
        request_body = json.loads(event['body'])
        parameter_value = request_body.get('parameter', '')
    except (json.JSONDecodeError, TypeError):
        parameter_value = ''

    # Return 400 if no parameter received or empty
    if not parameter_value or not parameter_value.strip():
        return {'statusCode': 400,
                'body': json.dumps({'error': 'Missing or empty parameter in body'})}

    if len(parameter_value) > 10000:
        return {'statusCode': 400,
                'body': json.dumps({'error': 'Parameter exceeds maximum length of 10000 characters'})}

    # Tokenize the input into individual words (lowercase, letters only)
    words = re.findall(r"[a-zA-Z']+", parameter_value.lower())
    if not words:
        return {'statusCode': 400,
                'body': json.dumps({'error': 'No valid words found in parameter'})}

    # Insert each word into DynamoDB
    for word in words:
        insert_ddbb(word)

    # Get the top 10 most common words
    top10 = get_top_10()

    response = upload_to_s3(top10)

    # Return the response with a 200 status code
    return {
        'statusCode': 200,
        'body': json.dumps({'url': response})
    }

def insert_ddbb(word):
    dynamodb = boto3.client('dynamodb')
    # Atomic upsert: ADD initializes the counter to 0 then increments by 1 in one call
    dynamodb.update_item(
        TableName=dynamodb_table_name,
        Key={'word': {'S': word}},
        UpdateExpression='ADD times :inc',
        ExpressionAttributeValues={':inc': {'N': '1'}}
    )

def get_top_10():
    dynamodb = boto3.client('dynamodb')
    items = []
    scan_kwargs = {'TableName': dynamodb_table_name}

    # Paginate through all items to handle tables larger than 1 MB
    while True:
        response = dynamodb.scan(**scan_kwargs)
        items.extend(response.get('Items', []))
        last_key = response.get('LastEvaluatedKey')
        if not last_key:
            break
        scan_kwargs['ExclusiveStartKey'] = last_key

    items_sorted = sorted(items, key=lambda x: int(x['times']['N']), reverse=True)
    top_10_elements = [{'word': item['word']['S'], 'times': int(item['times']['N'])}
                       for item in items_sorted[:10]]
    return {'top10words': top_10_elements}

def upload_to_s3(text):
    file_name = "top.json"
    lambda_path = "/tmp/" + file_name
    with open(lambda_path, 'w') as f:
        json.dump(text, f)
    s3 = boto3.client("s3")
    s3.upload_file(lambda_path, s3_bucket_name, file_name)

    try:
        response = s3.generate_presigned_url('get_object',
                                            Params={'Bucket': s3_bucket_name,
                                                    'Key': file_name},
                                            ExpiresIn=presigned_url_expiry)
    except ClientError as e:
        logging.error(e)
        return None

    return response
