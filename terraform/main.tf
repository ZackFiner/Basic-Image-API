provider "aws" { // 
  region = "us-west-1"

}

resource "aws_s3_bucket" "b" { // create an S3 bucket with the resource name 'b'
  bucket = "zackfiners-tf-test-bucket2" // name the bucket zackfiners-tf-test-bucket in AWS
  acl    = "private" // make it private
/*
    // you can add tags here if you want
  tags = { 
    Name        = "Terraform Test Bucket"
    Environment = "Dev"
  }*/
}



resource "aws_iam_role" "img_lambda_role" { // create a basic role for the lambda
  name = "img_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "img_lambda_iam_policy" {
    name = "default_lambda_policy"
    policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [{
		"Action": "s3:*",
		"Resource": "${aws_s3_bucket.b.arn}",
		"Effect": "Allow",
		"Sid": "zfdefaultlmbdpolicy"
	}]
}
EOF
}

resource "aws_iam_role_policy_attachment" "img_lambda_policy_attachment" {
    role = aws_iam_role.img_lambda_role.name // we use role name here
    policy_arn = aws_iam_policy.img_lambda_iam_policy.arn
}

module "lambda_maker" {
  source="./lambda_component"

  source_file_path = "${path.module}/../lambdas/"
  lambda_name = "getImage"
  lambda_role_arn = aws_iam_role.img_lambda_role.arn
  lambda_layers = ["arn:aws:lambda:us-west-1:202559052178:layer:imageProcessingLayer:4"]
  handler_name = "lambda_handler"
  lambda_runtime = "python3.8"
}


data "archive_file" "lambda_payload" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/getImage.py"
  output_path = "${path.module}/lambda_function_payload.zip"
}


resource "aws_lambda_function" "get_image_lambda" { // create a aws lambda function with the terraform handle test_lambda
  filename      = "lambda_function_payload.zip"// select the zip file containing the code that implements the lambda that we created above
  function_name = "getImage-tf" // the name of actual lambda on AWS
  role          = aws_iam_role.img_lambda_role.arn // select a role for the lambda
  handler       = "getImage.lambda_handler" // choose a handler name, this is the name of the file/function in payload.zip that serves as the entry point

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  #source_code_hash = filebase64sha256("lambda_function_payload.zip")

  runtime = "python3.8"
    layers = ["arn:aws:lambda:us-west-1:202559052178:layer:imageProcessingLayer:4"]
    /*
    // Below, you can set environment variables for the lambda
  environment {
    variables = {
      foo = "bar"
    }
  }*/
}
