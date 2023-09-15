terraform {
  backend "s3" {
    bucket  = "sqslambdapoc"
    key     = "infratest/sqs-poc/terraform.tfstate"
    region  = "us-west-2"
    encrypt = "true"
    #dynamodb_table = "lms-terraform-remote-state-infratest" # Statefile locking
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.52.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.2"
    }
  }
}

provider "aws" {
  region = "us-west-2"
  default_tags {
    tags = {
      Terraform = "true"
    }
  }
}