variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where NLB and Lambda will be deployed"
}

variable "subnet_ids" {
  description = "List of Subnet IDs for the Load Balancer"
  type        = list(string)
}

variable "lambda_s3_bucket" {
  description = "S3 bucket storing Lambda zip file"
}

variable "lambda_s3_key" {
  description = "S3 object key for Lambda zip file"
}

variable "domain_name" {
  description = "Custom domain for API Gateway"
}

