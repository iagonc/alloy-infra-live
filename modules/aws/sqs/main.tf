resource "aws_sqs_queue" "this" {
  name                        = var.queue_name
  delay_seconds               = var.delay_seconds
  max_message_size            = var.max_message_size
  message_retention_seconds   = 345600
  receive_wait_time_seconds   = 10
  visibility_timeout_seconds  = 30
}
