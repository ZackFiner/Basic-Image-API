import json
from PIL import Image
import io
import boto3
import botocore
import base64
from os import environ

client = boto3.client('s3')


def lambda_handler(event, context):
    print(event)
    if not event["pathParameters"] or "image_id" not in event["pathParameters"] or not event['pathParameters']["image_id"]:
        return {
            'headers': {
                "Content-Type": "application/json"
            },
            "statusCode": 400,
            'body': json.dumps({
                'error': "Could not parse request"
            })
        }

    image_id = event['pathParameters']["image_id"]
    file_like = io.BytesIO()
    try:
        client.download_fileobj(environ["s3_bucket"], "{id}.jpg".format(id=image_id), file_like)
    except botocore.exceptions.ClientError as ex:
        if ex.response['Error']['Code'] == "404":
            return {
                'headers': {
                    "Content-Type": "application/json"
                },
                "statusCode": 404,
                'body': json.dumps({
                    'error': "No such file exists"
                })
            }
        else:
            return {
                'headers': {
                    "Content-Type": "application/json"
                },
                "statusCode": 500,
                'body': json.dump({
                    'error': "An internal server error occured"
                })
            }
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
