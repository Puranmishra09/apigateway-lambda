provider "aws" {
  region = "us-east-1"
}

# Route 53 Hosted Zone (Ensure your domain is registered)
resource "aws_route53_zone" "puran" {
  name = "puran.com"
}

# SSL Certificate for API Gateway
resource "aws_acm_certificate" "puran_cert" {
  domain_name       = "puran.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "puran_api" {
  name          = "puran-api"
  protocol_type = "HTTP"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "puran_stage" {
  api_id      = aws_apigatewayv2_api.puran_api.id
  name        = "prod"
  auto_deploy = true
}

# API Gateway Custom Domain Name
resource "aws_apigatewayv2_domain_name" "puran_domain" {
  domain_name = "puran.com"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.puran_cert.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

# Route 53 Record for API Gateway
resource "aws_route53_record" "api_record" {
  zone_id = aws_route53_zone.puran.zone_id
  name    = "puran.com"
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.puran_domain.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.puran_domain.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# Lambda Function
resource "aws_lambda_function" "puran_lambda" {
  function_name    = "puran_function"
  role            = aws_iam_role.lambda_exec.arn
  handler        = "index.handler"
  runtime        = "nodejs18.x"
  filename       = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "apigw_lambda" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.puran_lambda.function_name
  principal     = "apigateway.amazonaws.com"
}

# API Gateway Integration with Lambda
resource "aws_apigatewayv2_integration" "puran_lambda_integration" {
  api_id           = aws_apigatewayv2_api.puran_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.puran_lambda.invoke_arn
}

# API Gateway Route
resource "aws_apigatewayv2_route" "puran_route" {
  api_id    = aws_apigatewayv2_api.puran_api.id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.puran_lambda_integration.id}"
}

# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

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

# IAM Policy for Lambda
resource "aws_iam_policy_attachment" "lambda_policy_attach" {
  name       = "lambda_policy_attachment"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
