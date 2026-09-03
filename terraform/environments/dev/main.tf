locals {
  cluster_name = "${var.project}-${var.environment}-eks"

  common_tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

module "vpc" {
  source = "../../modules/vpc"

  project      = var.project
  environment  = var.environment
  cluster_name = local.cluster_name

  vpc_cidr                 = var.vpc_cidr
  availability_zones       = var.availability_zones
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  single_nat_gateway       = var.single_nat_gateway

  tags = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  project     = var.project
  environment = var.environment

  tags = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  project      = var.project
  environment  = var.environment
  cluster_name = local.cluster_name

  kubernetes_version = var.kubernetes_version

  vpc_id                   = module.vpc.vpc_id
  control_plane_subnet_ids = module.vpc.private_app_subnet_ids
  node_subnet_ids          = module.vpc.private_app_subnet_ids

  cluster_role_arn          = module.iam.eks_cluster_role_arn
  node_role_arn             = module.iam.eks_node_role_arn
  alb_controller_policy_arn = module.iam.alb_controller_policy_arn

  endpoint_private_access = var.eks_endpoint_private_access
  endpoint_public_access  = var.eks_endpoint_public_access
  public_access_cidrs     = var.eks_public_access_cidrs

  node_instance_types = var.node_instance_types
  node_capacity_type  = var.node_capacity_type
  node_disk_size      = var.node_disk_size
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size

  log_retention_days = var.log_retention_days

  tags = local.common_tags
}

resource "random_password" "remember_me_key" {
  length  = 48
  special = false
}

module "rds" {
  source = "../../modules/rds"

  project     = var.project
  environment = var.environment

  vpc_id                     = module.vpc.vpc_id
  db_subnet_ids              = module.vpc.private_db_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]

  engine_version        = var.rds_engine_version
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type          = var.rds_storage_type

  db_name         = var.rds_db_name
  master_username = var.rds_master_username

  multi_az                     = var.rds_multi_az
  backup_retention_period      = var.rds_backup_retention_period
  backup_window                = var.rds_backup_window
  maintenance_window           = var.rds_maintenance_window
  deletion_protection          = var.rds_deletion_protection
  skip_final_snapshot          = var.rds_skip_final_snapshot
  monitoring_interval          = var.rds_monitoring_interval
  performance_insights_enabled = var.rds_performance_insights_enabled
  apply_immediately            = var.rds_apply_immediately
  secret_recovery_window_days  = var.secret_recovery_window_days
  app_remember_me_key          = random_password.remember_me_key.result
  log_retention_days           = var.log_retention_days

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# App IRSA role - grants the AutoCare pod's ServiceAccount (via the Secrets
# Store CSI Driver's AWS provider) read-only access to exactly one secret.
# Role name matches the placeholder documented in the autocare-deployment
# Helm chart's values.yaml: autocare-<env>-secrets-role.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "app_secrets_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.app_namespace}:${var.app_service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_secrets" {
  name               = "${var.project}-${var.environment}-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.app_secrets_assume.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "app_secrets_access" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [module.rds.app_secret_arn]
  }
}

resource "aws_iam_role_policy" "app_secrets" {
  name   = "${var.project}-${var.environment}-secrets-policy"
  role   = aws_iam_role.app_secrets.id
  policy = data.aws_iam_policy_document.app_secrets_access.json
}

module "ecr" {
  source = "../../modules/ecr"

  project     = var.project
  environment = var.environment

  repository_name            = var.ecr_repository_name
  image_tag_mutability       = var.ecr_image_tag_mutability
  scan_on_push               = var.ecr_scan_on_push
  max_tagged_image_count     = var.ecr_max_tagged_image_count
  untagged_image_expiry_days = var.ecr_untagged_image_expiry_days

  tags = local.common_tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  project     = var.project
  environment = var.environment

  vpc_id           = module.vpc.vpc_id
  eks_cluster_name = module.eks.cluster_name
  rds_instance_id  = module.rds.db_instance_id
  nat_gateway_ids  = module.vpc.nat_gateway_ids

  alarm_sns_email         = var.alarm_sns_email
  flow_log_retention_days = var.log_retention_days

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# SSM Parameter Store - non-secret runtime configuration published under
# /autocare/<environment>/* so the Jenkins CI/CD pipelines in the
# autocare-platform and autocare-deployment repos can discover everything
# they need (cluster name, ECR URL, IAM role ARN, secret ARN) at build time
# with a single `aws ssm get-parameters-by-path` call - no values are ever
# copy-pasted between repos by hand.
# ---------------------------------------------------------------------------

resource "aws_ssm_parameter" "eks_cluster_name" {
  name  = "/autocare/${var.environment}/eks_cluster_name"
  type  = "String"
  value = module.eks.cluster_name
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "ecr_repository_url" {
  name  = "/autocare/${var.environment}/ecr_repository_url"
  type  = "String"
  value = module.ecr.repository_url
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "app_secret_arn" {
  name  = "/autocare/${var.environment}/app_secret_arn"
  type  = "String"
  value = module.rds.app_secret_arn
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "app_irsa_role_arn" {
  name  = "/autocare/${var.environment}/app_irsa_role_arn"
  type  = "String"
  value = aws_iam_role.app_secrets.arn
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "aws_region" {
  name  = "/autocare/${var.environment}/aws_region"
  type  = "String"
  value = var.aws_region
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "namespace" {
  name  = "/autocare/${var.environment}/namespace"
  type  = "String"
  value = var.app_namespace
  tags  = local.common_tags
}
