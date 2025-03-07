output "lambda_arn" {
  value = aws_lambda_function.my_lambda.arn
}

output "api_gateway_url" {
  value = aws_api_gateway_rest_api.my_api.execution_arn
}

output "custom_domain" {
  value = "https://${aws_route53_record.api_record.name}"
}
