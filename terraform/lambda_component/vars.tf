variable "source_file_path" {
  type=string
}
variable "lambda_name" {
  type=string
}
variable "lambda_role_arn" {
  type=string
}
variable "lambda_layers" {
  type=list(string)
}
variable "handler_name" {
  type=string
}
variable "lambda_runtime" {
    type=string
}