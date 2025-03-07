output "api_gateway_url" {
  description = "The API Gateway Invoke URL"
  value       = aws_apigatewayv2_stage.puran_stage.invoke_url
}

output "custom_domain_url" {
  description = "The custom domain URL for API Gateway"
  value       = "https://${aws_apigatewayv2_domain_name.puran_domain.domain_name}"
}

output "lambda_arn" {
  description = "ARN of the deployed Lambda function"
  value       = aws_lambda_function.puran_lambda.arn
}
