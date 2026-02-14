output "instance_id" {
  value = aws_instance.stackpilot.id
}

output "public_ip" {
  value = aws_instance.stackpilot.public_ip
}

output "public_dns" {
  value = aws_instance.stackpilot.public_dns
}

output "security_group_id" {
  value = aws_security_group.stackpilot.id
}

output "api_port" {
  value = var.api_port
}

output "ssh_user" {
  value = "ubuntu"
}