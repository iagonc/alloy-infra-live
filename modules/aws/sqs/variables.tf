variable "queue_name" {
  type        = string
  description = "Name of the SQS queue"
}

variable "delay_seconds" {
  type        = number
  default     = 0
}

variable "max_message_size" {
  type        = number
  default     = 262144
}
