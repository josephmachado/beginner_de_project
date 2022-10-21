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

variable "key_name" {
  description = "EC2 key name"
  type        = string
  default     = "sde-key"
}

variable "instance_type" {
  description = "Instance type for EMR and EC2"
  type        = string
  default     = "m4.xlarge"
}
