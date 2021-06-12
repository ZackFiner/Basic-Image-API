provider "aws" { // 
  region = "us-west-1"

}
data "aws_caller_identity" "current" {

}

resource "aws_s3_bucket" "b" { // create an S3 bucket with the resource name 'b'
  bucket = var.bucket_name     // name the bucket zackfiners-tf-test-bucket in AWS
  acl    = "private"           // make it private
  /*
    // you can add tags here if you want
  tags = { 
    Name        = "Terraform Test Bucket"
    Environment = "Dev"
  }*/
}

// Create the role and add a policy to access the S3 bucket we created above

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
  name   = "default_lambda_policy"
  policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [{
		"Action": ["s3:*", "logs:*"],
		"Resource": "*",
		"Effect": "Allow",
		"Sid": "zfdefaultlmbdpolicy"
	}]
}
EOF
}

resource "aws_iam_role_policy_attachment" "img_lambda_policy_attachment" {
  role       = aws_iam_role.img_lambda_role.name // we use role name here
  policy_arn = aws_iam_policy.img_lambda_iam_policy.arn
}

module "getImage_module" { // create get lambda
  source = "./lambda_component"

  source_file_path = "${path.module}/../lambdas/"
  lambda_name      = "getImage"
  lambda_role_arn  = aws_iam_role.img_lambda_role.arn
  lambda_layers    = var.lambda_layers
  handler_name     = "lambda_handler"
  lambda_runtime   = "python3.8"
  s3_bucket_name   = var.bucket_name
}

module "uploadImage_module" { // create upload lambda
  source = "./lambda_component"

  source_file_path = "${path.module}/../lambdas/"
  lambda_name      = "uploadImage"
  lambda_role_arn  = aws_iam_role.img_lambda_role.arn
  lambda_layers    = var.lambda_layers
  handler_name     = "lambda_handler"
  lambda_runtime   = "python3.8"
  s3_bucket_name   = var.bucket_name
}

resource "aws_api_gateway_rest_api" "image_proc_api" {
  name               = "imageProcTF"
  binary_media_types = ["*/*"]

  description = "Image Processing API applied from terraform on ${timestamp()}" // this forces a redeployment
}

resource "aws_api_gateway_resource" "images" {
  parent_id   = aws_api_gateway_rest_api.image_proc_api.root_resource_id
  path_part = "images"
  rest_api_id = aws_api_gateway_rest_api.image_proc_api.id
}

resource "aws_api_gateway_resource" "img_id" {
  parent_id   = aws_api_gateway_resource.images.id
  path_part   = "{image_id}"
  rest_api_id = aws_api_gateway_rest_api.image_proc_api.id
}

resource "aws_api_gateway_method" "getImage_meth" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.img_id.id
  rest_api_id   = aws_api_gateway_rest_api.image_proc_api.id
}

resource "aws_api_gateway_method_response" "getImage_resp_meth" {
  http_method = aws_api_gateway_method.getImage_meth.http_method
  resource_id = aws_api_gateway_resource.img_id.id
  rest_api_id = aws_api_gateway_rest_api.image_proc_api.id
  status_code = "200"

  response_models = {"application/json" = "Empty"}
}

resource "aws_api_gateway_integration" "getImage_int" {
  http_method = aws_api_gateway_method.getImage_meth.http_method
  resource_id = aws_api_gateway_resource.img_id.id
  rest_api_id = aws_api_gateway_rest_api.image_proc_api.id

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.getImage_module.lambda_uri
}

resource "aws_api_gateway_integration_response" "getImage_resp_int" {
  http_method = aws_api_gateway_method.getImage_meth.http_method
  resource_id = aws_api_gateway_resource.img_id.id
  rest_api_id = aws_api_gateway_rest_api.image_proc_api.id
  status_code = aws_api_gateway_method_response.getImage_resp_meth.status_code
}

resource "aws_api_gateway_method" "uploadImage_meth" {
  authorization = "NONE"
  http_method   = "POST"
  rest_api_id   = aws_api_gateway_rest_api.image_proc_api.id
  resource_id   = aws_api_gateway_resource.images.id
}

resource "aws_api_gateway_method_response" "uploadImage_resp_meth" {
  http_method = aws_api_gateway_method.uploadImage_meth.http_method
  resource_id = aws_api_gateway_resource.images.id
  rest_api_id = aws_api_gateway_rest_api.image_proc_api.id
  status_code = "200"

  response_models = {"application/json" = "Empty"}
}

resource "aws_api_gateway_integration" "uploadImage_int" {
  http_method = aws_api_gateway_method.uploadImage_meth.http_method
  resource_id = aws_api_gateway_resource.images.id
  rest_api_id = aws_api_gateway_rest_api.image_proc_api.id

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.uploadImage_module.lambda_uri
}

resource "aws_api_gateway_integration_response" "uploadImage_resp_int" {
  http_method = aws_api_gateway_method.uploadImage_meth.http_method
  resource_id = aws_api_gateway_resource.images.id
  rest_api_id = aws_api_gateway_rest_api.image_proc_api.id
  status_code = aws_api_gateway_method_response.uploadImage_resp_meth.status_code
}



resource "aws_lambda_permission" "imgproc_lambda_get" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.getImage_module.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.image_proc_api.execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "imgproc_lambda_post" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.uploadImage_module.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.image_proc_api.execution_arn}/*/*/*"
}


// Deploy the API

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.image_proc_api.id

  triggers = {
     # redeploy if our api gateway definition of the api_gateway resource changes, not necessarily any of the
     # other resources the api gateway is dependent on do.
    redeplyoment = sha1(jsonencode(aws_api_gateway_rest_api.image_proc_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "img_lib_stg" {
        deployment_id = aws_api_gateway_deployment.deployment.id
        rest_api_id = aws_api_gateway_rest_api.image_proc_api.id
        stage_name = "api"

        description = "Deployed at ${timestamp()}"
}