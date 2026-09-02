project     = "autocare"
environment = "prod"
aws_region  = "us-east-1"

# ---------------------------------------------------------------------------
# Networking - one NAT Gateway per AZ for high availability
# ---------------------------------------------------------------------------
vpc_cidr                 = "10.0.0.0/16"
availability_zones       = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs      = ["10.0.0.0/24", "10.0.1.0/24"]
private_app_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
private_db_subnet_cidrs  = ["10.0.20.0/24", "10.0.21.0/24"]
single_nat_gateway       = false

# ---------------------------------------------------------------------------
# EKS - larger nodes, restrict the public API endpoint to trusted CIDRs
# (your office/VPN CIDR and your CI/CD egress IPs) before applying.
# ---------------------------------------------------------------------------
eks_endpoint_private_access = true
eks_endpoint_public_access  = true
eks_public_access_cidrs     = ["203.0.113.0/24"] # TODO: replace with real trusted CIDRs
node_instance_types         = ["t3.large"]
node_capacity_type          = "ON_DEMAND"
node_disk_size              = 50
node_desired_size           = 2
node_min_size               = 2
node_max_size               = 6
log_retention_days          = 180

# ---------------------------------------------------------------------------
# RDS - Multi-AZ, deletion protection, longer backup retention
# ---------------------------------------------------------------------------
rds_engine_version               = "8.0"
rds_instance_class               = "db.r6g.large"
rds_allocated_storage            = 100
rds_max_allocated_storage        = 500
rds_storage_type                 = "gp3"
rds_db_name                      = "autocare"
rds_master_username              = "autocare_admin"
rds_multi_az                     = true
rds_backup_retention_period      = 30
rds_deletion_protection          = true
rds_skip_final_snapshot          = false
rds_monitoring_interval          = 30
rds_performance_insights_enabled = true
rds_apply_immediately            = false
secret_recovery_window_days      = 30

# ---------------------------------------------------------------------------
# ECR
# ---------------------------------------------------------------------------
ecr_repository_name            = "autocare"
ecr_image_tag_mutability       = "IMMUTABLE"
ecr_scan_on_push               = true
ecr_max_tagged_image_count     = 20
ecr_untagged_image_expiry_days = 7

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------
app_namespace            = "autocare"
app_service_account_name = "autocare"

# ---------------------------------------------------------------------------
# Monitoring - set a real email to receive alarm notifications
# ---------------------------------------------------------------------------
alarm_sns_email = ""

tags = {
  Owner = "platform-team"
}
