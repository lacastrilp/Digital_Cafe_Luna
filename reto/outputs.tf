output "instance_id" {
  value = aws_instance.reto.id
}

output "instance_public_ip" {
  value = aws_instance.reto.public_ip
}

output "instance_private_ip" {
  value = aws_instance.reto.private_ip
}

output "queue_url" {
  value = aws_sqs_queue.reto.url
}
