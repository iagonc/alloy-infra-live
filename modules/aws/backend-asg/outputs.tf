# ------------------------------------------------------------------------------
# LOAD BALANCER
# ------------------------------------------------------------------------------

output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = module.load_balancer.dns_name
}

output "queue_url" {
  description = "URL of the SQS queue"
  value       = module.alloy_queue.queue_url
}

output "db_endpoint" {
  description = "Endpoint of the RDS Postgres DB"
  value       = module.alloy_db.db_host
}
