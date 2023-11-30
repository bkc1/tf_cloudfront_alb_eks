
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}


locals {
  name         = "eks-nextjs-example"
  cluster_name = "eks-nextjs-example-${random_string.suffix.result}"
  namespace    = "nextjs-sample-app"

  tags = {
    auto-delete = "no"   
    env         = local.name
  }
}

resource "random_string" "suffix" {
  length  = 6
  special = false
}

## VPC/Networking ##

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "eks-nextjs-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway      = true
  single_nat_gateway      = true
  enable_dns_hostnames    = true
  map_public_ip_on_launch = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}

## IAM resources ##

resource "aws_iam_role" "EKSClusterRole" {
  name = "EKSClusterRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role" "NodeGroupRole" {
  name = "EKSNodeGroupRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.EKSClusterRole.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.NodeGroupRole.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.NodeGroupRole.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.NodeGroupRole.name
}

## EKS Cluster ##

resource "aws_eks_cluster" "eks-cluster" {
  name     = local.cluster_name
  role_arn = aws_iam_role.EKSClusterRole.arn
  version  = "1.28"

  vpc_config {
    subnet_ids             = flatten([ module.vpc.public_subnets, module.vpc.private_subnets])
    endpoint_public_access = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy
  ]
}

## EKS Node Group and Addon's ##

variable "addons" {
  type = list(object({
    name    = string
  }))

  default = [
    {
      name    = "kube-proxy"
    },
    {
      name    = "vpc-cni"
    }
  ]
}

resource "aws_eks_addon" "addons" {
  for_each          = { for addon in var.addons : addon.name => addon }
  cluster_name      = aws_eks_cluster.eks-cluster.name
  addon_name        = each.value.name
  resolve_conflicts_on_create = "OVERWRITE"
}


resource "aws_eks_node_group" "node-ec2" {
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "m5_large-node_group"
  node_role_arn   = aws_iam_role.NodeGroupRole.arn
  subnet_ids      = flatten( module.vpc.public_subnets )

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  ami_type       = "AL2_x86_64"
  instance_types = ["m5.large"]
  capacity_type  = "ON_DEMAND"
  disk_size      = 20


  remote_access {
    ec2_ssh_key               = module.key_pair.key_pair_name
    source_security_group_ids = [aws_security_group.remote_access.id]
  }

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    module.key_pair
  ]
}

## SSH Access to EKS Nodes ##

resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

module "key_pair" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "~> 2.0"

  key_name_prefix    = local.name
  create_private_key = true

  tags = local.tags
}

resource "local_sensitive_file" "this" {
  content  = module.key_pair.private_key_pem
  filename = "${path.module}/sshkey-${local.name}"
}

# Only allow access from your IP 
data "external" "myipaddr" {
  program = ["bash", "-c", "curl -s 'https://ipinfo.io/json'"]
}

resource "aws_security_group" "remote_access" {
  name_prefix = "${local.name}-remote-access"
  description = "Allow remote SSH access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.external.myipaddr.result.ip}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  
  tags = local.tags
}

## EKS ALB Controller ##

resource "null_resource" "kubectl" {
  provisioner "local-exec" {
      command = "aws eks --region ${var.region} update-kubeconfig --name ${aws_eks_cluster.eks-cluster.name}"
  }
  depends_on = [ aws_eks_cluster.eks-cluster ]
}

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
}

data "aws_eks_cluster" "example" {
  name = aws_eks_cluster.eks-cluster.name
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = concat([data.tls_certificate.cluster.certificates.0.sha1_fingerprint])
  url             = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
}

module "load_balancer_controller" {
  source = "git::https://github.com/DNXLabs/terraform-aws-eks-lb-controller.git"

  cluster_identity_oidc_issuer     = data.aws_eks_cluster.example.identity[0].oidc[0].issuer
  cluster_identity_oidc_issuer_arn = aws_iam_openid_connect_provider.cluster.arn
  cluster_name                     = aws_eks_cluster.eks-cluster.name
  
  depends_on = [ null_resource.kubectl ]
}