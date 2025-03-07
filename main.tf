provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Subnets
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
}

# Security Group for Lambda
resource "aws_security_group" "lambda_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Network Load Balancer
resource "aws_lb" "my_nlb" {
  name               = "my-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets           = [aws_subnet.public_subnet.id]
}

# NLB Target Group
resource "aws_lb_target_group" "my_tg" {
  name     = "my-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.my_vpc.id
}

# Target Group Attachment (Lambda through VPC Link)
resource "aws_lb_target_group_attachment" "lambda_attachment" {
  target_group_arn = aws_lb_target_group.my_tg.arn
  target_id        = aws_lambda_function.my_lambda.arn
}

# API Gateway VPC Link
resource "aws_apigatewayv2_vpc_link" "my_vpc_link" {
  name        = "my-vpc-link"
  subnet_ids  = [aws_subnet.private_subnet.id]
  security_group_ids = [aws_security_group.lambda_sg.id]
}

# Lambda Function
resource "aws_lambda_function" "my_lambda" {
  function_name = "web-service-lambda"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  filename      = "lambda.zip"
  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "my_api" {
  name          = "MyAPI"
  protocol_type = "HTTP"
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.my_api.id
  integration_type = "HTTP_PROXY"
  integration_uri  = aws_lb.my_nlb.arn
  connection_type  = "VPC_LINK"
  connection_id    = aws_apigatewayv2_vpc_link.my_vpc_link.id
}

# API Gateway Route
resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.my_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.my_api.id
  name        = "default"
  auto_deploy = true
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# IAM Policy for Lambda
resource "aws_iam_policy" "lambda_policy" {
  name = "lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "logs:CreateLogGroup"
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}
