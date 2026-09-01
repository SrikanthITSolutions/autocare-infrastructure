terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Intentionally local state: this configuration creates the S3 bucket that
  # every other Terraform root module (environments/dev, environments/prod)
  # uses as its remote backend. Bootstrapping the backend cannot itself
  # depend on the backend it creates.
}

provider "aws" {
  region = var.aws_region
}
