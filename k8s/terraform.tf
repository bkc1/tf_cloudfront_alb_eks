terraform {


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.28.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.13.0"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.24.0"
    }

  }


  required_version = "~> 1.4"
}

