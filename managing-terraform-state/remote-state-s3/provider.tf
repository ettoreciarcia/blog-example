terraform {
  backend "s3" {
    bucket         = "terraform-state-remote-s3-sdf2"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform_locks"
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = "~> 1.5.5"
}

provider "aws" {
  region = "eu-west-1"
}