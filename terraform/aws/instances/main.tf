/*# Backend must remain commented until the Bucket
 and the DynamoDB table are created. 
 After the creation you can uncomment it,
 run "terraform init" and then "terraform apply" */

terraform {
   backend "s3" {
     bucket         = "gcp-terraform-state-backend"
     key            = "global/s3/terraform.tfstate"
     region         = "us-east-1"
     dynamodb_table = "gcp_terraform_state"
     encrypt        = true
   }
}

provider "aws" {
  region = "us-east-1"
#  profile = "myAWS"  
}

resource "aws_s3_bucket" "bucket" {
    bucket = "gcp-terraform-state-backend"

    lifecycle {
        prevent_destroy = true
    }

    versioning {
        enabled = true
    }

    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default {
                sse_algorithm = "AES256"
            }
        }
    }

    object_lock_enabled = true  # Set the top-level parameter for object lock

    #object_lock_configuration {
    #    object_lock_enabled = "Enabled"
    #}
    
    tags = {
        Name = "S3 Remote Terraform State Store"
    }
}


resource "aws_dynamodb_table" "terraform-lock" {
    name = "gcp_terraform_state"
    hash_key = "LockID"
    read_capacity = 20
    write_capacity = 20

    attribute {
        name = "LockID"
        type = "S"
    }

    tags = {
        Name = "var.dynamo-tag"
    }
}

resource "aws_iam_policy" "policydocument" {
  name        = "tf-policydocument"
  policy      = data.aws_iam_policy_document.example.json
}

data "aws_iam_policy_document" "example" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::may28-terraform-state-backend/*"
    ]
  }
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

# Correct outputs referencing the module outputs
output "master_node_public_ip" {
  value = module.ec2_instance.master_node_public_ip
}

output "worker_node_public_ips" {
  value = module.ec2_instance.worker_node_public_ips
}
