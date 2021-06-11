import json
from PIL import Image
import io
import boto3
import base64
from os import environ

client = boto3.client('s3')


def lambda_handler(event, context):
    if "pathParameters" not in event or "image_id" not in event["pathParameters"] or not event['pathParameters']["image_id"]:
        return {
            "statusCode": 400,
            'body': {
                'error': "Could not parse request"
            }
        }

    image_id = event['pathParameters']["image_id"]
    file_like = io.BytesIO()
    client.download_fileobj(environ["s3_bucket_name"], "{id}.jpg".format(id=image_id), file_like)
    file_like.seek(0)
    b64_encoded = base64.b64encode(file_like.getvalue()).decode()

    # TODO implement
    return {
        'statusCode': 200,
        'headers': {
            "Content-Type": "image/jpeg"
        },
        'body': b64_encoded,
        "isBase64Encoded": True

    }
