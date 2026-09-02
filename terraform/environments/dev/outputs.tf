output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "Private application subnet IDs"
  value       = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "Private database subnet IDs"
  value       = module.vpc.private_db_subnet_ids
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate authority data for the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "IAM OIDC provider ARN for the cluster (used for IRSA)"
  value       = module.eks.oidc_provider_arn
}

output "alb_controller_role_arn" {
  description = "IAM role ARN to annotate the aws-load-balancer-controller service account with"
  value       = module.eks.alb_controller_role_arn
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN used by the EBS CSI driver add-on"
  value       = module.eks.ebs_csi_role_arn
}

output "configure_kubectl" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL for the AutoCare application image"
  value       = module.ecr.repository_url
}

output "rds_endpoint" {
  description = "RDS MySQL connection endpoint (host:port)"
  value       = module.rds.db_endpoint
}

output "rds_db_name" {
  description = "Initial database name"
  value       = module.rds.db_name
}

output "app_secret_arn" {
  description = "AWS Secrets Manager secret ARN holding DB_HOST/DB_PORT/DB_NAME/DB_USERNAME/DB_PASSWORD/REMEMBER_ME_KEY (also published to SSM at /autocare/<env>/app_secret_arn)"
  value       = module.rds.app_secret_arn
}

output "app_irsa_role_arn" {
  description = "IAM role ARN for the AutoCare pod's ServiceAccount to assume via IRSA when reading the app secret (also published to SSM at /autocare/<env>/app_irsa_role_arn) - set this as the serviceAccount.annotations.\"eks.amazonaws.com/role-arn\" Helm value"
  value       = aws_iam_role.app_secrets.arn
}

output "alarms_sns_topic_arn" {
  description = "SNS topic ARN used for infrastructure CloudWatch alarms"
  value       = module.monitoring.sns_topic_arn
}

output "ssm_parameter_path" {
  description = "SSM Parameter Store path prefix under which all cross-repo runtime configuration for this environment is published"
  value       = "/autocare/${var.environment}"
}
