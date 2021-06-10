import json
from PIL import Image, ImageOps
import urllib.request as url
import io
import boto3
import uuid

client = boto3.client('s3')


def lambda_handler(event, context):
    # TODO implement
    print(event)
    if 'body' not in event:
        return {
            'statusCode': 400,
            'body': {
                'error': 'Error parsing request body'
            }
        }
    body = json.loads(event['body'])
    print(body)
    if 'img_url' not in body:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'No image URL in request'})
        }
    img_url = body['img_url']

    fd = url.urlopen(img_url)  # create file descriptor for img
    img_file = io.BytesIO(fd.read())  # read file as bytes
    img = Image.open(img_file)  # open bytes file with PIL

    # Image manipulation here
    new_img = ImageOps.grayscale(img)

    new_file_obj = io.BytesIO()
    new_img.save(new_file_obj, "JPEG")
    new_file_obj.seek(0)

    image_id = str(uuid.uuid4())

    client.upload_fileobj(new_file_obj, "zack-finers-image-bucket", "{img_id}.jpg".format(img_id=image_id))

    return {
        'statusCode': 201,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': json.dumps({
            'image_id': image_id
        })

    }
