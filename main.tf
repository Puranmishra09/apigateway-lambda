provider "aws" {
  region = "us-east-1"
}
# Create an S3 bucket for Lambda
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "my-lambda-bucket"
}

# Upload lambda.zip to S3
resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "lambda.zip"
  source = "lambda.zip"   # Path to your local file
  etag   = filemd5("lambda.zip")
}

# Lambda function referencing S3 bucket
resource "aws_lambda_function" "puran_lambda" {
  function_name = "puran_function"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_role.arn

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_zip.key
}

# Create a new IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_role" {
  name = "new_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach Basic Execution Policy to IAM Role
resource "aws_iam_policy_attachment" "lambda_basic_execution" {
  name       = "lambda_execution_policy_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Request an ACM Certificate for API Gateway
resource "aws_acm_certificate" "api_cert" {
  domain_name       = "puran.com"
  validation_method = "DNS"
}

# Create an API Gateway Custom Domain Name
resource "aws_api_gateway_domain_name" "my_custom_domain" {
  domain_name              = "puran.com"
  regional_certificate_arn = aws_acm_certificate.api_cert.arn
  endpoint_configuration {
    types = ["EDGE"]
  }
}

# Create a REST API in API Gateway
resource "aws_api_gateway_rest_api" "puran_api" {
  name        = "puran_api"
  description = "API for Puran services"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "puran_api_deployment" {
  depends_on = [aws_api_gateway_rest_api.puran_api]

  rest_api_id = aws_api_gateway_rest_api.puran_api.id
  stage_name  = "prod"
}

# API Gateway Lambda Integration
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.puran_api.id
  parent_id   = aws_api_gateway_rest_api.puran_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.puran_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.puran_api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.puran_lambda.invoke_arn
}

# API Gateway Stage
resource "aws_api_gateway_stage" "puran_stage" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.puran_api.id
  deployment_id = aws_api_gateway_deployment.puran_api_deployment.id
}

# Lambda Permission for API Gateway Invocation
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.puran_lambda.function_name
  principal     = "apigateway.amazonaws.com"
}
