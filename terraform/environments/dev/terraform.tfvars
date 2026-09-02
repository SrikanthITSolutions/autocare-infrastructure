project     = "autocare"
environment = "dev"
aws_region  = "us-east-1"

# ---------------------------------------------------------------------------
# Networking - dev uses a single shared NAT Gateway to save cost
# ---------------------------------------------------------------------------
vpc_cidr                 = "10.0.0.0/16"
availability_zones       = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs      = ["10.0.0.0/24", "10.0.1.0/24"]
private_app_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
private_db_subnet_cidrs  = ["10.0.20.0/24", "10.0.21.0/24"]
single_nat_gateway       = true

# ---------------------------------------------------------------------------
# EKS - small node group, public endpoint open for teaching convenience
# (restrict eks_public_access_cidrs to your IP/VPN in any shared environment)
# ---------------------------------------------------------------------------
eks_endpoint_private_access = true
eks_endpoint_public_access  = true
eks_public_access_cidrs     = ["0.0.0.0/0"]
node_instance_types         = ["t3.small"] # this AWS account is Free Tier restricted - t3.medium was rejected; confirmed free-tier-eligible types here: t3.micro, t3.small, t4g.micro, t4g.small
node_capacity_type          = "ON_DEMAND"
node_disk_size              = 20
node_desired_size           = 2
node_min_size               = 2
node_max_size               = 4
log_retention_days          = 30

# ---------------------------------------------------------------------------
# RDS - single-AZ, small instance, protections relaxed for easy teardown
# ---------------------------------------------------------------------------
rds_engine_version               = "8.0"
rds_instance_class               = "db.t3.micro" # Free Tier eligible RDS class on this account
rds_allocated_storage            = 20            # Free Tier RDS storage cap is 20 GiB
rds_max_allocated_storage        = 100
rds_storage_type                 = "gp3"
rds_db_name                      = "autocare"
rds_master_username              = "autocare_admin"
rds_multi_az                     = false
rds_backup_retention_period      = 1 # AWS Free Tier / restricted-plan accounts cap this low; raise once the account plan is upgraded
rds_deletion_protection          = false
rds_skip_final_snapshot          = true
rds_monitoring_interval          = 60
rds_performance_insights_enabled = true
rds_apply_immediately            = true
secret_recovery_window_days      = 0

# ---------------------------------------------------------------------------
# ECR
# ---------------------------------------------------------------------------
ecr_repository_name            = "autocare"
ecr_image_tag_mutability       = "IMMUTABLE"
ecr_scan_on_push               = true
ecr_max_tagged_image_count     = 10
ecr_untagged_image_expiry_days = 7

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------
app_namespace            = "autocare"
app_service_account_name = "autocare"

# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------
alarm_sns_email = ""

tags = {
  Owner = "platform-team"
}
