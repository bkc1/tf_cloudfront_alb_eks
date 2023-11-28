
// terraform output eks cluster name
output "eks_cluster_name" {
  description = "The name of the EKS cluster."
  value       = aws_eks_cluster.eks-cluster.name
}
