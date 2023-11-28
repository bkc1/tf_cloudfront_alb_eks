
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.nextjs.domain_name
}