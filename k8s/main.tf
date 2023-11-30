provider "aws" {
  region = var.region
}

locals {
  namespace             = "nextjs-sample-app"
}

// get EKS cluster name from main tf project
data "terraform_remote_state" "eks_cluster" {
  backend = "local"
  config = {
    path = "../terraform.tfstate"
  }
}

resource "null_resource" "kubectl" {
  provisioner "local-exec" {
      command = "aws eks --region ${var.region} update-kubeconfig --name ${data.terraform_remote_state.eks_cluster.outputs.eks_cluster_name}"
  }
}

resource "kubernetes_namespace_v1" "nextjs" {
  metadata {
    name = local.namespace
  }
  depends_on = [ null_resource.kubectl ]
}

data "kubectl_path_documents" "deployment" {
  pattern = "./manifests/nextjs-deployment.yaml"
}

data "kubectl_path_documents" "service" {
  pattern = "./manifests/nextjs-service.yaml"
}

data "kubectl_path_documents" "ingress" {
  pattern = "./manifests/nextjs-ingress.yaml"
}

resource "kubectl_manifest" "deployment" {
  yaml_body = data.kubectl_path_documents.deployment.documents[0]
  depends_on = [ 
    kubernetes_namespace_v1.nextjs, 
  ]
}

resource "kubectl_manifest" "service" {
  yaml_body = data.kubectl_path_documents.service.documents[0]
  depends_on = [ 
    kubectl_manifest.deployment,
    kubernetes_namespace_v1.nextjs, 
  ]
}

resource "kubectl_manifest" "ingress" {
  yaml_body = data.kubectl_path_documents.ingress.documents[0]
  depends_on = [ 
    kubectl_manifest.service,
    kubernetes_namespace_v1.nextjs, 
  ]
}