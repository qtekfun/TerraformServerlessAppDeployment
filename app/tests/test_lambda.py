"""Unit tests for lambda_function.py — all AWS calls are mocked."""

import json
import os
import sys
import unittest
from unittest.mock import MagicMock, patch, call

# Set required env vars before importing the module under test
os.environ.setdefault('S3_BUCKET_NAME', 'test-bucket')
os.environ.setdefault('DYNAMODB_TABLE', 'test-table')
os.environ.setdefault('PRESIGNED_URL_EXPIRY', '600')

# Stub boto3 and botocore so the module can be imported without AWS SDK installed
boto3_stub = MagicMock()
sys.modules.setdefault('boto3', boto3_stub)
botocore_stub = MagicMock()
sys.modules.setdefault('botocore', botocore_stub)

# ClientError must be a real exception subclass so that raise/except works in tests
class _ClientError(Exception):
    def __init__(self, error_response, operation_name):
        self.response = error_response
        self.operation_name = operation_name
        super().__init__(str(error_response))

botocore_exceptions_stub = MagicMock()
botocore_exceptions_stub.ClientError = _ClientError
sys.modules['botocore.exceptions'] = botocore_exceptions_stub

# Ensure the app directory is on the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

import lambda_function


def _make_event(body):
    """Build a minimal API Gateway proxy event."""
    return {'body': json.dumps(body)}


class TestLambdaHandler(unittest.TestCase):

    def test_missing_parameter_returns_400(self):
        event = _make_event({})
        result = lambda_function.lambda_handler(event, None)
        self.assertEqual(result['statusCode'], 400)
        self.assertIn('error', json.loads(result['body']))

    def test_empty_parameter_returns_400(self):
        event = _make_event({'parameter': '   '})
        result = lambda_function.lambda_handler(event, None)
        self.assertEqual(result['statusCode'], 400)

    def test_parameter_exceeding_max_length_returns_400(self):
        event = _make_event({'parameter': 'a' * 10001})
        result = lambda_function.lambda_handler(event, None)
        self.assertEqual(result['statusCode'], 400)

    def test_non_alpha_only_parameter_returns_400(self):
        event = _make_event({'parameter': '123 456'})
        result = lambda_function.lambda_handler(event, None)
        self.assertEqual(result['statusCode'], 400)

    @patch('lambda_function.upload_to_s3', return_value='https://presigned-url')
    @patch('lambda_function.get_top_10', return_value={'top10words': []})
    @patch('lambda_function.insert_ddbb')
    def test_valid_sentence_calls_insert_for_each_word(self, mock_insert, mock_top10, mock_upload):
        event = _make_event({'parameter': 'hello world hello'})
        result = lambda_function.lambda_handler(event, None)
        self.assertEqual(result['statusCode'], 200)
        # 'hello' and 'world' are unique tokens; insert called once per unique occurrence
        self.assertEqual(mock_insert.call_count, 3)
        mock_insert.assert_any_call('hello')
        mock_insert.assert_any_call('world')

    @patch('lambda_function.upload_to_s3', return_value='https://presigned-url')
    @patch('lambda_function.get_top_10', return_value={'top10words': []})
    @patch('lambda_function.insert_ddbb')
    def test_response_body_contains_url(self, _mock_insert, _mock_top10, _mock_upload):
        event = _make_event({'parameter': 'test'})
        result = lambda_function.lambda_handler(event, None)
        body = json.loads(result['body'])
        self.assertIn('url', body)
        self.assertEqual(body['url'], 'https://presigned-url')


class TestWordTokenization(unittest.TestCase):

    def test_sentence_splits_into_lowercase_words(self):
        """Verify tokenization via insert_ddbb call counts from lambda_handler."""
        with patch('lambda_function.upload_to_s3', return_value='https://url'), \
             patch('lambda_function.get_top_10', return_value={'top10words': []}), \
             patch('lambda_function.insert_ddbb') as mock_insert:
            event = _make_event({'parameter': 'Hello, World! Hello.'})
            lambda_function.lambda_handler(event, None)
            calls = [c[0][0] for c in mock_insert.call_args_list]
            self.assertIn('hello', calls)
            self.assertIn('world', calls)
            self.assertEqual(calls.count('hello'), 2)


class TestInsertDdbb(unittest.TestCase):

    @patch('lambda_function.boto3')
    def test_insert_calls_update_item_atomically(self, mock_boto3):
        mock_client = MagicMock()
        mock_boto3.client.return_value = mock_client

        lambda_function.insert_ddbb('python')

        mock_client.update_item.assert_called_once_with(
            TableName='test-table',
            Key={'word': {'S': 'python'}},
            UpdateExpression='ADD times :inc',
            ExpressionAttributeValues={':inc': {'N': '1'}}
        )


class TestGetTop10(unittest.TestCase):

    @patch('lambda_function.boto3')
    def test_paginates_until_no_last_evaluated_key(self, mock_boto3):
        mock_client = MagicMock()
        mock_boto3.client.return_value = mock_client

        page1 = {
            'Items': [{'word': {'S': 'apple'}, 'times': {'N': '5'}}],
            'LastEvaluatedKey': {'word': {'S': 'apple'}}
        }
        page2 = {
            'Items': [{'word': {'S': 'banana'}, 'times': {'N': '3'}}],
        }
        mock_client.scan.side_effect = [page1, page2]

        result = lambda_function.get_top_10()

        self.assertEqual(mock_client.scan.call_count, 2)
        words = [item['word'] for item in result['top10words']]
        self.assertIn('apple', words)
        self.assertIn('banana', words)

    @patch('lambda_function.boto3')
    def test_returns_top_10_sorted_by_frequency(self, mock_boto3):
        mock_client = MagicMock()
        mock_boto3.client.return_value = mock_client

        items = [{'word': {'S': f'word{i}'}, 'times': {'N': str(i)}} for i in range(15)]
        mock_client.scan.return_value = {'Items': items}

        result = lambda_function.get_top_10()

        self.assertEqual(len(result['top10words']), 10)
        counts = [item['times'] for item in result['top10words']]
        self.assertEqual(counts, sorted(counts, reverse=True))


class TestUploadToS3(unittest.TestCase):

    @patch('lambda_function.boto3')
    def test_returns_presigned_url_on_success(self, mock_boto3):
        mock_client = MagicMock()
        mock_boto3.client.return_value = mock_client
        mock_client.generate_presigned_url.return_value = 'https://s3-presigned-url'

        result = lambda_function.upload_to_s3({'top10words': []})

        self.assertEqual(result, 'https://s3-presigned-url')
        mock_client.upload_file.assert_called_once()

    @patch('lambda_function.boto3')
    def test_returns_none_on_client_error(self, mock_boto3):
        # Use the same ClientError that lambda_function imported (may be a stub)
        client_error_cls = lambda_function.ClientError
        mock_client = MagicMock()
        mock_boto3.client.return_value = mock_client
        mock_client.generate_presigned_url.side_effect = client_error_cls(
            {'Error': {'Code': 'NoSuchBucket', 'Message': 'Not found'}}, 'GeneratePresignedUrl'
        )

        result = lambda_function.upload_to_s3({'top10words': []})

        self.assertIsNone(result)


if __name__ == '__main__':
    unittest.main()
