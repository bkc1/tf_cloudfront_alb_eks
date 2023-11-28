provider "aws" {
  region = var.region
}

// get EKS cluster name from main tf project
data "terraform_remote_state" "eks_cluster" {
  backend = "local"
  config = {
    path = "../terraform.tfstate"
  }
}

locals {
  namespace             = "nextjs-sample-app"
  ingress_svc_name      = "ingress-nextjs"
  ingress_load_balancer_tags = {
    "ingress.k8s.aws/resource" = "LoadBalancer"
    "ingress.k8s.aws/stack"    = "${local.namespace}/${local.ingress_svc_name}"
    "elbv2.k8s.aws/cluster"    = data.terraform_remote_state.eks_cluster.outputs.eks_cluster_name
  }
}


// Get K8S ingress ALB metadata from tags
data "aws_lb" "ingress_load_balancer" {
  tags = local.ingress_load_balancer_tags
}

resource "aws_cloudfront_distribution" "nextjs" {
  origin {
    #domain_name = "k8s-nextjssa-ingressn-dc3356f841-405522504.us-west-2.elb.amazonaws.com"
    domain_name = data.aws_lb.ingress_load_balancer.dns_name
    origin_id   = data.aws_lb.ingress_load_balancer.dns_name
      custom_origin_config {
        http_port              = "80"
        https_port             = "443"
        origin_protocol_policy = "http-only"
        origin_ssl_protocols   = ["TLSv1.2", "TLSv1.1"]
      }
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = local.namespace

  # AWS Managed Caching Policy (CachingDisabled)
  default_cache_behavior {
    # Using the CachingDisabled managed policy ID:
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = data.aws_lb.ingress_load_balancer.dns_name
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}