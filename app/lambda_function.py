# lambda_function.py

import json
# import pymysql
import os

import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Retrieve environment variables
s3_bucket_name = os.environ['S3_BUCKET_NAME']
rds_host = os.environ['RDS_HOST']
rds_username = os.environ['RDS_USERNAME']
rds_password = os.environ['RDS_PASSWORD']
rds_db_name = os.environ['RDS_DB_NAME']

def lambda_handler(event, context):

    logging.info(f"Received event: {json.dumps(event)}")
    
    # connection = pymysql.connect(host=rds_host,
    #                             user=rds_username,
    #                             password=rds_password,
    #                             db=rds_db_name,
    #                             connect_timeout=5)
    
    # connection.close()

    # Extract the parameter from the incoming JSON request
    try:
        request_body = json.loads(event['body'])
        parameter_value = request_body.get('parameter', 'unknown')
    except json.JSONDecodeError:
        parameter_value = 'unknown'

    # Construct the response body including the parameter value
    response_body = f"Hello, I'm fine. Your env vars are {s3_bucket_name} and {rds_host}.\n"
    response_body += f"The parameter you sent me was {parameter_value}\n"
    response_body += f"event is {event}\n"

    # Return the response with a 200 status code
    return {
        'statusCode': 200,
        'body': response_body
    }
