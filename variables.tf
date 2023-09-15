variable "namespace" {
  type        = string
  description = "Namespace, which could be your organization name or abbreviation (e.g. 'eg' or 'cp')"
  default     = "lms"
}

variable "environment" {
  type        = string
  description = "Environment"
  default     = "infratest"
}

variable "name" {
  type    = string
  default = "lms"
}

variable "lambda_memory_size" {
  type        = string
  description = "Amount of memory in MB Lambda Function can use at runtime"
  default     = 128
}

variable "cw_log_group_retention_period" {
  type        = string
  description = "Time period in Days for which logs will be retained in Cloudwatch"
  default     = 90
}

variable "lambda_timeout" {
  type        = string
  description = "Amount of time Lambda Function has to run in seconds"
  default     = 60
}
