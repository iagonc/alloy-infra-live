# ------------------------------------------------------------------------------
# RDS SUBNET AND SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_db_subnet_group" "this" {
  name       = "${var.db_identifier}-subnet-group"
  subnet_ids = var.subnets

  tags = {
    Name = "${var.db_identifier}-subnet-group"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.db_identifier}-sg"
  description = "Security Group for RDS"
  vpc_id      = var.vpc_id

  ingress {
  from_port   = 5432
  to_port     = 5432
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------------------------------
# RDS INSTANCE
# ------------------------------------------------------------------------------

resource "aws_db_instance" "this" {
  identifier             = var.db_identifier
  engine                 = "postgres"
  engine_version         = var.engine_version
  instance_class         = var.instance_class
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  db_name     = var.db_name
  username = var.db_username
  password = var.db_password

  publicly_accessible = true
  skip_final_snapshot = true

  tags = {
    Name = var.db_identifier
  }
}
