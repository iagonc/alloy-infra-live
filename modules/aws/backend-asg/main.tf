# ------------------------------------------------------------------------------
# LOCALS
# ------------------------------------------------------------------------------

locals {
  vpc_id          = data.aws_vpc.default.id
  vpc_cidr_blocks = data.aws_vpc.default.cidr_block_associations[*].cidr_block
  cidr_blocks     = var.custom_cidr != null ? concat(local.vpc_cidr_blocks, [var.custom_cidr]) : local.vpc_cidr_blocks
  server_port     = 80
}

# ------------------------------------------------------------------------------
# ALB SECURITY GROUP
# ------------------------------------------------------------------------------

module "lb_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  name        = format("%s-lb", var.cluster_name)
  description = format("%s - LB", var.cluster_name)
  vpc_id      = local.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = local.server_port
      to_port     = local.server_port
      protocol    = "tcp"
      description = "Allow inbound traffic on server port"
      cidr_blocks = join(",", local.cidr_blocks)
    },
  ]

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = join(",", local.cidr_blocks)
    },
  ]
}

# ------------------------------------------------------------------------------
# LOAD BALANCER
# ------------------------------------------------------------------------------

module "load_balancer" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.11.0"

  name                       = var.cluster_name
  vpc_id                     = local.vpc_id
  subnets                    = data.aws_subnets.default.ids
  enable_deletion_protection = false

  create_security_group = false
  security_groups       = [module.lb_security_group.security_group_id]

  listeners = {
    http = {
      port     = local.server_port
      protocol = "HTTP"
      forward = {
        target_group_key = "http"
      }
    }
  }

  target_groups = {
    http = {
      name              = "${var.cluster_name}-http"
      protocol          = "HTTP"
      port              = local.server_port
      target_type       = "instance"
      create_attachment = false
    }
  }
}

# ------------------------------------------------------------------------------
# ASG SECURITY GROUP
# ------------------------------------------------------------------------------

module "asg_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  name        = format("%s-ec2", var.cluster_name)
  description = format("%s - EC2 instances", var.cluster_name)
  vpc_id      = local.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "all-all"
      description              = "Allow traffic from ALB"
      source_security_group_id = module.lb_security_group.security_group_id
    },
  ]

  ingress_with_self = [
    {
      rule        = "all-all"
      description = "Allow all traffic among ASG instances"
    },
  ]

  egress_rules = ["all-all"]
}

resource "aws_security_group_rule" "allow_ssh_ingress" {
  security_group_id = module.asg_security_group.security_group_id

  type        = "ingress"
  cidr_blocks = local.cidr_blocks
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  description = "Allow SSH access"
}

resource "aws_security_group_rule" "allow_postgres_ingress" {
  security_group_id = module.asg_security_group.security_group_id

  type        = "ingress"
  cidr_blocks = local.cidr_blocks
  from_port   = 5432
  to_port     = 5432
  protocol    = "tcp"
  description = "Allow PostgreSQL traffic"
}

# ------------------------------------------------------------------------------
# EC2 POLICY
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "rds_sqs_access_policy" {
  name        = format("%s-extended-access-policy", var.cluster_name)
  description = "Allow EC2 to access all RDS/SQS actions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = "rds:*"
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "sqs:*"
        Resource = "*"
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# AUTO SCALING GROUP
# ------------------------------------------------------------------------------

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "8.0.0"

  name            = var.cluster_name
  use_name_prefix = false

  min_size              = var.asg_min_size
  max_size              = var.asg_max_size
  desired_capacity      = var.asg_desired_size
  protect_from_scale_in = var.protect_from_scale_in

  vpc_zone_identifier = data.aws_subnets.default.ids

  termination_policies = [
    "OldestInstance",
  ]

  launch_template_use_name_prefix = false
  update_default_version          = true
  disable_api_termination         = var.disable_api_termination

  instance_type = var.instance_type
  image_id      = data.aws_ami.ubuntu.id
  key_name      = var.key_pair_name

  # IAM Role and Instance Profile
  create_iam_instance_profile = true
  iam_role_name               = "${var.cluster_name}-ec2-role"
  iam_role_path               = "/ec2/"
  iam_role_description        = "IAM Role for EC2 instances in the Auto Scaling Group"
  iam_role_policies =  {
    RdsAndSqsPolicy = aws_iam_policy.rds_sqs_access_policy.arn
  }

  user_data = base64encode(templatefile("${path.module}/user-data/user-data.sh", {
    db_host  = module.alloy_db.db_host,
    sqs_url  = module.alloy_queue.queue_url,
  }))

  security_groups = [module.asg_security_group.security_group_id]
}

# ------------------------------------------------------------------------------
# ATTACH ASG TO THE ALB TARGET GROUP
# ------------------------------------------------------------------------------

resource "aws_autoscaling_traffic_source_attachment" "asg_lb_attach" {
  for_each = module.load_balancer.target_groups

  autoscaling_group_name = module.asg.autoscaling_group_name

  traffic_source {
    identifier = each.value.arn
    type       = "elbv2"
  }
}

# ------------------------------------------------------------------------------
# MODULE: SQS
# ------------------------------------------------------------------------------

module "alloy_queue" {
  source = "/root/alloy-infra-live/modules/aws/sqs"

  queue_name       = "${var.cluster_name}-rebate-webhook-queue"
  delay_seconds    = 0
  max_message_size = 262144
}

# ------------------------------------------------------------------------------
# MODULE: RDS
# ------------------------------------------------------------------------------

module "alloy_db" {
  source = "/root/alloy-infra-live/modules/aws/rds"

  db_identifier = "${var.cluster_name}-db"
  db_name       = "alloy_db"
  db_username   = "alloy_user"
  db_password   = "ChangeThisPassword123"
  subnets       = data.aws_subnets.default.ids
  vpc_id        = local.vpc_id
}

# ------------------------------------------------------------------------------
# SCALING POLICIES & CLOUDWATCH ALARMS (SQS ALARMS)
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "asg_high_sqs" {
  alarm_name                = "${var.cluster_name}-HighSQS"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  threshold                 = 1
  metric_name               = "ApproximateNumberOfMessagesVisible"
  namespace                 = "AWS/SQS"
  statistic                 = "Average"
  period                    = 60
  alarm_description         = "Scale out if SQS has >= 1 messages"
  alarm_actions             = [aws_autoscaling_policy.scale_out_sqs.arn]

  dimensions = {
    QueueName = module.alloy_queue.queue_name
  }
}

resource "aws_autoscaling_policy" "scale_out_sqs" {
  name                   = "${var.cluster_name}-ScaleOutSqsPolicy"
  autoscaling_group_name = module.asg.autoscaling_group_name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 2
  cooldown               = 30
}

resource "aws_cloudwatch_metric_alarm" "asg_low_sqs" {
  alarm_name                = "${var.cluster_name}-LowSQS"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = 1
  threshold                 = 1
  metric_name               = "ApproximateNumberOfMessagesVisible"
  namespace                 = "AWS/SQS"
  statistic                 = "Average"
  period                    = 60
  alarm_description         = "Scale in if SQS has 0 messages"
  alarm_actions             = [aws_autoscaling_policy.scale_in_sqs.arn]

  dimensions = {
    QueueName = module.alloy_queue.queue_name
  }
}

resource "aws_autoscaling_policy" "scale_in_sqs" {
  name                   = "${var.cluster_name}-ScaleInSqsPolicy"
  autoscaling_group_name = module.asg.autoscaling_group_name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -2
  cooldown               = 30
}