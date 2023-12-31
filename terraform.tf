terraform {


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.28.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.4"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.13.0"
    }



  }


  required_version = "~> 1.4"
}

