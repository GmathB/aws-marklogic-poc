# Primary outputs
output "instance_id" {
  description = "The ID of the MarkLogic EC2 instance"
  value       = aws_instance.marklogic_node_1.id
}

output "private_ip" {
  description = "The private IP of the MarkLogic EC2 instance"
  value       = aws_instance.marklogic_node_1.private_ip
}

output "instance_id_1" {
  description = "The ID of the MarkLogic EC2 instance (AZ: ap-south-1a)"
  value       = aws_instance.marklogic_node_1.id
}

output "private_ip_1" {
  description = "The private IP of the MarkLogic EC2 instance (AZ: ap-south-1a)"
  value       = aws_instance.marklogic_node_1.private_ip
}

output "vpc_flow_logs_group" {
  description = "CloudWatch Log Group for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}

output "vpc_endpoints" {
  description = "VPC Interface Endpoints for private connectivity"
  value = {
    ssm              = aws_vpc_endpoint.ssm.id
    ec2messages      = aws_vpc_endpoint.ec2messages.id
    ssmmessages      = aws_vpc_endpoint.ssmmessages.id
    secrets_manager  = aws_vpc_endpoint.secrets_manager.id
    s3_gateway       = aws_vpc_endpoint.s3.id
    cloudwatch_logs  = aws_vpc_endpoint.cloudwatch_logs.id
  }
}

output "ssm_port_forward_command" {
  description = "Command to access MarkLogic Admin Console via SSM port forwarding"
  value       = "aws ssm start-session --target ${aws_instance.marklogic_node_1.id} --document-name AWS-StartPortForwardingSession --parameters \"portNumber=8001,localPortNumber=8001\" --region ap-south-1"
}