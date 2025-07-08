# versions.tf - Defines required providers and their versions for the root module

terraform {
  required_version = ">= 1.0" # Or your preferred Terraform version

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Or specify a more precise version like "5.x.x"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
