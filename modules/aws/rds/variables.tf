variable "db_identifier" {
  type        = string
  description = "Identifier/name for the RDS instance"
}

variable "db_name" {
  type        = string
  description = "Database name"
}

variable "db_username" {
  type        = string
  description = "Database username"
}

variable "db_password" {
  type        = string
  description = "Database password"
}

variable "engine_version" {
  type        = string
  default     = "13"
  description = "Postgres engine version"
}

variable "instance_class" {
  type        = string
  default     = "db.t3.micro"
  description = "RDS instance size"
}

variable "subnets" {
  type        = list(string)
  description = "Subnets where the RDS will be placed (usually private)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for RDS"
}
