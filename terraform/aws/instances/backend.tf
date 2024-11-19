terraform {
   backend "s3" {
     bucket         = "gcp-new-microservices"
     key            = "global/s3/terraform.tfstate"
     region         = "us-east-1"
     encrypt        = true
   }
}

