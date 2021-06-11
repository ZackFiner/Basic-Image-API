/*
data "archive_file" "lambda_payload" {
  type        = "zip"
  source_file = "${var.source_file_path}/${var.lambda_name}.py"
  output_path = "${path.module}/${var.lambda_name}.zip"
}*/

resource "aws_s3_bucket_object" "obj" {
  bucket  = "${var.s3_bucket_name}-sourcecode"
  key     = "${var.lambda_name}.py"
  source  = "${var.source_file_path}/${var.lambda_name}.py"

  etag    = filemd5("${var.source_file_path}/${var.lambda_name}.py")
}

resource "aws_lambda_function" "lambda" { // create a aws lambda function with the terraform handle test_lambda
  //filename      = "${path.module}/${var.lambda_name}.zip"// select the zip file containing the code that implements the lambda that we created above
  s3_bucket     = "${var.s3_bucket_name}-sourcecode" // or just use our source code s3
  s3_key        = "${var.lambda_name}.py"

  function_name = "${var.lambda_name}-tf" // the name of actual lambda on AWS
  role          = var.lambda_role_arn // select a role for the lambda
  handler       = "${var.lambda_name}.${var.handler_name}" // choose a handler name, this is the name of the file/function in payload.zip that serves as the entry point

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  #source_code_hash = filebase64sha256("lambda_function_payload.zip")

  runtime = var.lambda_runtime
  layers = var.lambda_layers
    
    // Below, you can set environment variables for the lambda
  environment {
    variables = {
      s3_bucket = var.s3_bucket_name
    }
  }
}

output "lambda_uri" {
  value=aws_lambda_function.lambda.invoke_arn
}
output "lambda_function_name" {
    value = aws_lambda_function.lambda.function_name
}