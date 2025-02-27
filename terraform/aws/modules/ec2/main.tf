resource "aws_security_group" "instance-sg" {
  name        = "Ks Node SG"
  description = "SG for Kubeadm Nodes"
  vpc_id      = var.vpc_id  # Add this line

  dynamic "ingress" {
    for_each = toset(range(length(var.inbound_from_port)))
    content {
      from_port   = var.inbound_from_port[ingress.key]
      to_port     = var.inbound_to_port[ingress.key]
      protocol    = var.inbound_protocol[ingress.key]
      cidr_blocks = [var.inbound_cidr[ingress.key]]
    }
  }

  dynamic "egress" {
    for_each = toset(range(length(var.outbound_from_port)))
    content {
      from_port   = var.outbound_from_port[egress.key]
      to_port     = var.outbound_to_port[egress.key]
      protocol    = var.outbound_protocol[egress.key]
      cidr_blocks = [var.outbound_cidr[egress.key]]
    }
  }
}


resource "aws_instance" "example" {
  count         = var.instance_count
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = element(var.subnet_ids, count.index)

  # Add support for user_data
  user_data = var.user_data

  tags = {
    Name = "${var.instance_name}-${count.index}"
  }
}


# Output the list of created instances so they can be referenced outside this module
#output "instances" {
#  value = aws_instance.example
#}

output "master_node_public_ip" {
  value = aws_instance.example[0].public_ip
}

output "worker_node_public_ips" {
  value = aws_instance.example[*].public_ip
}

