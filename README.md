# Terraform Reference  - Deploying a NextJS app on EKS, fronted by Cloudfront 

This demo project is deployed in two parts to simplify Terraform (TF) dependency management.  
1) The main TF project deploys an EKS cluster, EC2 node-group, AWS Load Balancer Controller add-on, followed by a K8s deployment of a base NextJS container image (from Docker Hub).
2) The secondary TF project deploys a Cloudfront Distro with a custom origin using the ingress ALB created by the AWS Load Balancer Controller. The Cloudfront caching behavior uses the `CachingDisabled` Managed policy, intended for dynamic content. Secondary origins can be created to cache static content. 

## Architecture

![](./CF-ALB-EKS.png "Reference architecture").

## Prereqs

This was developed and tested with Terraform `v1.5.7`, AWScli `v2.13.18`. It is strongly recommended to deploy this is a sandbox or non-production account. 

# Usage

Set the desired AWS region in the `variables.tf` files.

## Deploying with Terraform

Deploy Part-1 from the root project directory...
```
terraform init  ## initialize Terraform
terraform plan  ## Review what Terraform will do
terraform apply ## Deploy the resources
```

After Part-1 is complete, deploy Part-2...
```
cd cloudfront
terraform init
terraform plan
terraform apply
```

Tear-down the resources in reverse order starting with part 2, then part 1. 
```
terraform destroy
```

## Accessing the site

Note the `cloudfront_domain_name` output.  The NextJS example app should be reachable via a web browser at this domain. 