output "queue_url" {
  value = aws_sqs_queue.main.url
}

output "asg_name" {
  value = aws_autoscaling_group.workers.name
}