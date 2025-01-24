output "db_host" {
  description = "The endpoint of the RDS instance"
  value = replace(aws_db_instance.this.endpoint, ":5432", "")
}

output "rds_security_group_id" {
  description = "The security group ID for the RDS instance"
  value       = aws_security_group.rds_sg.id
}
