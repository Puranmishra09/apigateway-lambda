# ==============================
# ✅ Provider Configuration
# ==============================
provider "aws" {
  region = "us-east-1"
}

# ==============================
# ✅ VPC Configuration (Modify if needed)
# ==============================
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ==============================
# ✅ Security Group for Lambda
# ==============================
resource "aws_security_group" "lambda_sg" {
  name        = "lambda-security-group"
  description = "Allow Lambda to access NLB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
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

# ==============================
# ✅ IAM Role for Lambda Execution
# ==============================
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

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

resource "aws_iam_policy" "lambda_vpc_policy" {
  name        = "lambda-vpc-policy"
  description = "Policy for Lambda to access VPC and write logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_vpc_policy.arn
}

# ==============================
# ✅ Lambda Function in VPC
# ==============================
resource "aws_lambda_function" "my_lambda" {
  function_name = "web-service-lambda"
  filename      = "lambda.zip"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_role.arn

  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# ==============================
# ✅ Network Load Balancer (NLB)
# ==============================
resource "aws_lb" "nlb" {
  name               = "nlb-for-lambda"
  internal           = false
  load_balancer_type = "network"
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "tg" {
  name     = "lambda-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = data.aws_vpc.default.id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# ==============================
# ✅ API Gateway with VPC Link
# ==============================
resource "aws_apigatewayv2_vpc_link" "vpc_link" {
  name               = "api-vpc-link"
  security_group_ids = [aws_security_group.lambda_sg.id]
  subnet_ids         = data.aws_subnets.default.ids
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "lambda-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "HTTP_PROXY"
  connection_type  = "VPC_LINK"
  connection_id    = aws_apigatewayv2_vpc_link.vpc_link.id
  integration_uri  = aws_lb.nlb.arn
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# ==============================
# ✅ Route 53 for Custom Domain
# ==============================
resource "aws_route53_zone" "my_domain" {
  name = "mycustomdomain.com"
}

resource "aws_apigatewayv2_domain_name" "api_custom_domain" {
  domain_name = "api.mycustomdomain.com"

  domain_name_configuration {
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id"  # Replace with your ACM cert ARN
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "api_mapping" {
  api_id      = aws_apigatewayv2_api.http_api.id
  domain_name = aws_apigatewayv2_domain_name.api_custom_domain.id
  stage       = aws_apigatewayv2_stage.default.id
}

resource "aws_route53_record" "api_dns" {
  zone_id = aws_route53_zone.my_domain.zone_id
  name    = "api.mycustomdomain.com"
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.api_custom_domain.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api_custom_domain.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}
