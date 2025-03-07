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

# ✅ Create API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name        = "MyAPIGateway"
  description = "API Gateway with VPC Link"
}

# ✅ Create VPC Link for API Gateway → NLB
resource "aws_api_gateway_vpc_link" "vpc_link" {
  name        = "my-vpc-link"
  target_arns = [aws_lb.my_nlb.arn]
}

# ✅ Create API Gateway Custom Domain Name
resource "aws_api_gateway_domain_name" "custom_domain" {
  domain_name     = var.api_subdomain
  certificate_arn = aws_acm_certificate_validation.cert.certificate_arn
}

# ✅ Create API Gateway Base Path Mapping
resource "aws_api_gateway_base_path_mapping" "mapping" {
  domain_name = aws_api_gateway_domain_name.custom_domain.domain_name
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
}

# ✅ Route 53 Hosted Zone (Skip if already exists)
resource "aws_route53_zone" "my_zone" {
  name = var.domain_name
}

# ✅ ACM SSL Certificate
resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# ✅ Create Route 53 DNS Record for ACM Validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.my_zone.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

# ✅ Validate ACM Certificate
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ✅ Create Route 53 Alias Record to Point to API Gateway
resource "aws_route53_record" "api_record" {
  zone_id = aws_route53_zone.my_zone.zone_id
  name    = var.api_subdomain
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.custom_domain.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.custom_domain.cloudfront_zone_id
    evaluate_target_health = false
  }
}
