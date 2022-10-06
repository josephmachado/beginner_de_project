variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "bucket_prefix" {
  description = "Bucket prefix for our datalake"
  type        = string
  default     = "sde-data-lake-"
}
