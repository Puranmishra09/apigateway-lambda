provider "aws" {
  region = var.region
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# Attach policy for Lambda permissions
resource "aws_iam_policy_attachment" "lambda_policy" {
  name       = "lambda-policy-attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Function
resource "aws_lambda_function" "my_lambda" {
  function_name = "my_lambda_function"
  role          = aws_iam_role.lambda_role.arn

  s3_bucket     = var.lambda_s3_bucket
  s3_key        = var.lambda_s3_key

  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
}

# API Gateway
resource "aws_api_gateway_rest_api" "my_api" {
  name        = "MyAPIGateway"
  description = "API Gateway for Lambda behind VPC Link"
}

# VPC Link for API Gateway (to connect with NLB)
resource "aws_api_gateway_vpc_link" "vpc_link" {
  name        = "my-vpc-link"
  target_arns = [aws_lb.nlb.arn]
}

# Network Load Balancer (NLB)
resource "aws_lb" "nlb" {
  name               = "my-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.subnet_ids
}

# Target Group for NLB
resource "aws_lb_target_group" "nlb_target_group" {
  name     = "nlb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

# Register Lambda as a Target in NLB
resource "aws_lb_target_group_attachment" "lambda_attachment" {
  target_group_arn = aws_lb_target_group.nlb_target_group.arn
  target_id        = aws_lambda_function.my_lambda.arn
}

# Route53 Record for Custom Domain
resource "aws_route53_record" "api_record" {
  zone_id = data.aws_route53_zone.my_zone.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.my_custom_domain.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.my_custom_domain.cloudfront_zone_id
    evaluate_target_health = false
  }
}

data "aws_route53_zone" "my_zone" {
  name = var.domain_name
}

resource "aws_api_gateway_domain_name" "my_custom_domain" {
  domain_name = var.domain_name
}
