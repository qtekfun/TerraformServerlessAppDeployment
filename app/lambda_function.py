# lambda_function.py

import json
# import pymysql
import os

# Retrieve environment variables
s3_bucket_name = os.environ['S3_BUCKET_NAME']
rds_host = os.environ['RDS_HOST']
rds_username = os.environ['RDS_USERNAME']
rds_password = os.environ['RDS_PASSWORD']
rds_db_name = os.environ['RDS_DB_NAME']

def lambda_handler(event, context):

    # connection = pymysql.connect(host=rds_host,
    #                             user=rds_username,
    #                             password=rds_password,
    #                             db=rds_db_name,
    #                             connect_timeout=5)
    
    # connection.close()

    # Return the response with a 200 status code
    return {
        'statusCode': 200,
        'body': f"Hello, I'm fine. Your env vars are {s3_bucket_name} and {rds_host}"
    }
