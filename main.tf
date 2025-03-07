provider "aws" {
  region = "us-east-1"
}

# ✅ Create Security Group for Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "lambda-security-group"
  description = "Allow traffic from NLB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.nlb_sg.id] # Accept traffic from NLB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ✅ Create Security Group for NLB
resource "aws_security_group" "nlb_sg" {
  name        = "nlb-security-group"
  description = "Allow API Gateway traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow traffic from API Gateway
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ✅ Create Network Load Balancer
resource "aws_lb" "my_nlb" {
  name               = "my-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.nlb_sg.id]
}

# ✅ Create Lambda in VPC
resource "aws_lambda_function" "my_lambda" {
  function_name = "web-service-lambda"
  filename      = "lambda.zip"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_role.arn

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}
