variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "domain_name" {
  description = "The custom domain for API Gateway"
  default     = "puran.com"
}

variable "lambda_function_name" {
  description = "The Lambda function name"
  default     = "puran_function"
}
