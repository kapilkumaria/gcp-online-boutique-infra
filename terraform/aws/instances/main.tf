/*# Backend must remain commented until the Buckets
 and the DynamoDB table are created. 
 After the creation you can uncomment it,
 run "terraform init" and then "terraform apply" */

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

  # Remove the key_name to prevent conflicts
  # key_name = "devops1"

  user_data = <<EOF
#cloud-config
users:
  - default
  - name: ubuntu
    ssh-authorized-keys:
      - ${chomp(jsonencode(file("/home/ubuntu/.ssh/id_rsa_terraform.pub")))}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    shell: /bin/bash
EOF
}


# Correct outputs referencing the module outputs
output "master_node_public_ip" {
  value = module.ec2_instance.master_node_public_ip
}

output "worker_node_public_ips" {
  value = module.ec2_instance.worker_node_public_ips
}

# Add the local_file resource to dynamically create the Ansible inventory
resource "local_file" "ansible_inventory" {
  filename = "./../../../ansible/inventory.ini"
  

  content = <<EOT
[controlplane]
ansible_host=${module.ec2_instance.master_node_public_ip}

[workers]
%{ for index, ip in module.ec2_instance.worker_node_public_ips }
worker${index + 1} ansible_host=${ip}
%{ endfor }

[k8s:children]
controlplane
workers
EOT
}

resource "null_resource" "ansible_provisioner" {
  depends_on = [
    local_file.ansible_inventory,
    module.ec2_instance
    
  ]

  provisioner "local-exec" {
    command = <<-EOT
      sleep 70 # Reduced wait time since we're using public IPs
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
        -i ./../../../ansible/inventory.ini \
        ./../../../ansible/site.yaml \
        --private-key=/root/.ssh/id_rsa_terraform \
        -u ubuntu         
    EOT
  }
}
