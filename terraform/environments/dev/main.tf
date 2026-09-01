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

  tags = local.common_tags
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
