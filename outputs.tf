output "api_gateway_url" {
  value = aws_api_gateway_domain_name.custom_domain.domain_name
}

output "nlb_dns" {
  value = aws_lb.my_nlb.dns_name
}

output "lambda_function_name" {
  value = aws_lambda_function.my_lambda.function_name
}
