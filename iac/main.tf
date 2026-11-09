data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "worker" {
  name   = "${var.project_name}-worker-sg"
  vpc_id = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/${var.project_name}/worker"
  retention_in_days = 1
}

resource "aws_launch_template" "worker" {
  name_prefix   = "${var.project_name}-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.worker.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.worker.id]
  }

  monitoring {
    enabled = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    queue_url    = aws_sqs_queue.main.url
    region       = var.region
    project_name = var.project_name
  }))
}

resource "aws_autoscaling_group" "workers" {
  name                = "${var.project_name}-asg"
  min_size            = 1
  max_size            = 3
  vpc_zone_identifier = data.aws_subnets.default.ids

  metrics_granularity = "1Minute"
  enabled_metrics     = ["GroupInServiceInstances", "GroupDesiredCapacity", "GroupTotalInstances"]

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-worker"
    propagate_at_launch = true
  }

  depends_on = [aws_cloudwatch_log_group.worker]
}

# Target tracking: mantiene ~backlog_objetivo mensajes por instancia
resource "aws_autoscaling_policy" "backlog" {
  name                      = "${var.project_name}-backlog-per-instance"
  autoscaling_group_name    = aws_autoscaling_group.workers.name
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = 120

  target_tracking_configuration {
    target_value = var.backlog_objetivo

    customized_metric_specification {
      metrics {
        id    = "m1"
        label = "Mensajes en cola"
        metric_stat {
          metric {
            namespace   = "AWS/SQS"
            metric_name = "ApproximateNumberOfMessagesVisible"
            dimensions {
              name  = "QueueName"
              value = aws_sqs_queue.main.name
            }
          }
          stat = "Sum"
        }
        return_data = false
      }

      metrics {
        id    = "m2"
        label = "Instancias en servicio"
        metric_stat {
          metric {
            namespace   = "AWS/AutoScaling"
            metric_name = "GroupInServiceInstances"
            dimensions {
              name  = "AutoScalingGroupName"
              value = aws_autoscaling_group.workers.name
            }
          }
          stat = "Average"
        }
        return_data = false
      }

      metrics {
        id          = "e1"
        label       = "Backlog por instancia"
        expression  = "m1 / m2"
        return_data = true
      }
    }
  }
}