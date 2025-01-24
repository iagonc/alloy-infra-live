# ------------------------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------------------------

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# BASIC CLUSTER INFO
# ------------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
  default     = "alloy-cluster"
}

# ------------------------------------------------------------------------------
# ASG CONFIG
# ------------------------------------------------------------------------------

variable "asg_min_size" {
  description = "Min size of the ASG"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Max size of the ASG"
  type        = number
  default     = 3
}

variable "asg_desired_size" {
  description = "Desired size of the ASG"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type for the ASG"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Key pair name (for debugging; not recommended in production)"
  type        = string
  default     = null
}

variable "disable_api_termination" {
  description = "Disables manual termination from EC2 console/API (not from ASG scaling events)"
  type        = bool
  default     = false
}

variable "protect_from_scale_in" {
  description = "Enable ASG scale-in protection"
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# CUSTOM CIDR
# ------------------------------------------------------------------------------

variable "custom_cidr" {
  description = "Optional extra CIDR block for ingress"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# REPO URL (FOR USER_DATA)
# ------------------------------------------------------------------------------

variable "repo_url" {
  description = "Git repo URL for the app"
  type        = string
  default     = "https://github.com/iagonc/xpto"
}
