provider "aws" {
  region = "us-east-1"
}

module "ec2_instance" {
  source = "../modules/ec2"

  instance_name  = "k8s-node"
  ami_id         = "ami-0866a3c8686eaeeba"
  instance_type  = "t2.medium"
  key_name       = "devops1"
  subnet_ids     = ["subnet-0caef41d3608c34ef", "subnet-09d2f4fbd2bffd05a"]
  instance_count = 3

  inbound_from_port  = ["0", "6443", "22", "30000"]
  inbound_to_port    = ["65000", "6443", "22", "32768"]
  inbound_protocol   = ["TCP", "TCP", "TCP", "TCP"]
  inbound_cidr       = ["172.31.0.0/16", "0.0.0.0/0", "0.0.0.0/0", "0.0.0.0/0"]
  outbound_from_port = ["0"]
  outbound_to_port   = ["0"]
  outbound_protocol  = ["-1"]
  outbound_cidr      = ["0.0.0.0/0"]
}

# Output for the master node's public IP
output "master_public_ip" {
  value       = aws_instance.example[0].public_ip
  description = "Public IP of the master node"
}

# Output for the worker nodes' public IPs
output "worker_public_ips" {
  value       = [for instance in aws_instance.example[1:] : instance.public_ip"]"
  description = "Public IPs of the worker nodes"
}

# Output for all instance private IPs (master and workers)
output "private_ips" {
  value       = [for instance in aws_instance.example : instance.private_ip]
  description = "Private IPs of all nodes (master and workers)"
}
