# lambda_function.py

import json

def lambda_handler(event, context):

    # Return the response with a 200 status code
    return {
        'statusCode': 200,
        'body': "Hello, I'm fine"
    }
