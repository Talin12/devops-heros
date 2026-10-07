variable "aws_region" {
  description = "AWS region for every resource in this config"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Prefix used in bucket names and tags"
  type        = string
  default     = "session18"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "enable_versioning" {
  description = "Turn on S3 object versioning"
  type        = bool
  default     = false
}
