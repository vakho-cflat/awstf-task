# variables

variable "s3bucketname" {
  description = "aws s3 bucket"
  type        = string
  default     = "devops-tbc-vtabatadze"
}

variable "postgresql-password" {
  description = "postgresql password"
  type        = string
  default     = "postgres25-password"
}
