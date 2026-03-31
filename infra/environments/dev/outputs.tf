output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "frontend_bucket" { value = aws_s3_bucket.frontend.bucket }
output "cloudfront_domain_name" { value = aws_cloudfront_distribution.frontend.domain_name }
output "frontend_ecr" { value = aws_ecr_repository.frontend.repository_url }
output "backend_ecr" { value = module.ecr.repository_url }
output "worker_ecr" { value = aws_ecr_repository.worker.repository_url }
