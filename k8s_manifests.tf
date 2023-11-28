
resource "kubernetes_namespace" "nextjs" {
  metadata {
    name = local.namespace
  }
}

data "kubectl_path_documents" "docs" {
  pattern = "./manifests/*.yaml"
}

resource "kubectl_manifest" "test" {
  for_each  = toset(data.kubectl_path_documents.docs.documents)
  yaml_body = each.value
  depends_on = [ 
    aws_eks_cluster.eks-cluster,
    kubernetes_namespace.nextjs, 
    module.load_balancer_controller
  ]
}