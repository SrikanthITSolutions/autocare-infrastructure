# AutoCare AWS Infrastructure

Production-oriented Terraform for deploying the AutoCare Spring Boot platform on
Amazon EKS, connected securely to Amazon RDS MySQL. This is the AWS foundation
layer only — no Kubernetes application manifests and no CI/CD server are
created here yet.

## 1. Architecture

```
                                   Internet
                                      │
                         Route 53 (optional, bring your
                         own hosted zone / DNS record)
                                      │
                    ┌─────────────────────────────────┐
                    │   Public Subnets (2 AZs)         │
                    │   Internet Gateway                │
                    │   AWS Load Balancer (ALB)         │──┐ created by
                    │   NAT Gateway(s)                  │  │ AWS Load Balancer
                    └─────────────────────────────────┘  │ Controller (later)
                                      │                      │
                    ┌─────────────────────────────────┐  │
                    │  Private App Subnets (2 AZs)      │◄─┘
                    │  Amazon EKS (control plane ENIs)  │
                    │  EKS Managed Node Group           │
                    │  AutoCare Spring Boot pods         │
                    └─────────────────────────────────┘
                                      │  MySQL 3306
                                      │  (security-group restricted)
                    ┌─────────────────────────────────┐
                    │  Private DB Subnets (2 AZs)       │
                    │  Amazon RDS MySQL (Multi-AZ)      │
                    └─────────────────────────────────┘
```

- The VPC spans **2 Availability Zones** with three subnet tiers: public,
  private-application (EKS), and private-database (RDS).
- Only the public subnets route to the Internet Gateway. The application
  subnets route outbound-only traffic through NAT Gateway(s). The database
  subnets have **no route to the internet at all**.
- EKS worker nodes are **private only** — no public IPs, reached only through
  the load balancer created later by the AWS Load Balancer Controller.
- RDS is **never publicly accessible** and only reachable from the EKS
  cluster/node security group on port 3306.
- Database credentials are never stored in Terraform state or source control:
  RDS's native `manage_master_user_password` feature stores and rotates the
  master password in **AWS Secrets Manager** automatically.

This repository intentionally stops at the AWS foundation. The next stages
(Kubernetes manifests / Helm charts for the AutoCare Deployment, Service,
Ingress, and the Jenkins CI/CD server) are separate, later efforts that will
consume the outputs of this Terraform (EKS cluster name, ECR repository URL,
RDS endpoint and secret ARN, IRSA role ARNs).

## 2. Folder structure

```
terraform/
├── bootstrap/                  # One-time: creates the S3 remote state bucket
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── modules/
│   ├── vpc/                    # VPC, subnets, route tables, NAT/IGW
│   ├── iam/                    # EKS cluster/node roles, ALB controller policy
│   ├── eks/                    # EKS cluster, OIDC, node group, IRSA, add-ons
│   ├── rds/                    # RDS MySQL, subnet group, security group
│   ├── ecr/                    # ECR repository + lifecycle policy
│   └── monitoring/             # VPC flow logs, SNS, CloudWatch alarms
├── environments/
│   ├── dev/                    # Root module for the dev environment
│   │   ├── versions.tf
│   │   ├── providers.tf
│   │   ├── backend.hcl.example
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   └── prod/                   # Root module for the prod environment
│       └── (same layout as dev, production-sized defaults)
├── .gitignore
└── README.md
```

Each environment folder is a **self-contained Terraform root module** with its
own state, backend, and variables — this is what makes `dev` and `prod`
independently plannable/applyable/destroyable. Both call the same shared
modules under `modules/`, so a change to networking, EKS, or RDS behavior is
made once and rolled out to each environment on its own schedule.

## 3. What each major resource is for

### VPC module (`modules/vpc`)
| Resource | Purpose |
|---|---|
| `aws_vpc` | The `10.0.0.0/16` network, with DNS support/hostnames enabled (required by EKS). |
| `aws_internet_gateway` | Allows the public subnets (and the future ALB) to reach the internet. |
| `aws_subnet.public` | 2 subnets (one per AZ) hosting the ALB and NAT Gateways. |
| `aws_subnet.private_app` | 2 subnets hosting EKS control-plane ENIs and worker nodes — no direct internet route. |
| `aws_subnet.private_db` | 2 subnets hosting RDS — no NAT/internet route at all. |
| `aws_eip` / `aws_nat_gateway` | Lets private subnets make outbound calls (pulling container images, calling AWS APIs) without being reachable from the internet. One shared NAT (dev, cost-conscious) or one per AZ (prod, HA). |
| `aws_route_table.public/private_app/private_db` | Three distinct route table families, matching the "separate DB route tables" requirement — the DB route tables carry only the implicit local VPC route. |

### IAM module (`modules/iam`)
| Resource | Purpose |
|---|---|
| `aws_iam_role.eks_cluster` | Assumed by the EKS control plane; `AmazonEKSClusterPolicy` grants only what the control plane needs. |
| `aws_iam_role.eks_node` | Assumed by worker node EC2 instances; attached policies grant CNI networking, ECR pull, and SSM (no SSH keys needed) — nothing more. |
| `aws_iam_policy.alb_controller` | The official AWS Load Balancer Controller policy, attached later to an IRSA role — least-privilege permissions to manage ALBs/target groups on the controller's behalf. |

### EKS module (`modules/eks`)
| Resource | Purpose |
|---|---|
| `aws_eks_cluster` | The managed Kubernetes control plane, deployed with its ENIs in the private application subnets, with all 5 control-plane log types shipped to CloudWatch. |
| `aws_cloudwatch_log_group.eks_cluster` | Owns the control-plane log retention policy (instead of the AWS default of "never expire"). |
| `aws_iam_openid_connect_provider` | Trusts the cluster's OIDC issuer so Kubernetes service accounts can assume IAM roles directly (IRSA) — no static AWS credentials stored in pods. |
| `aws_eks_node_group` | The managed, auto-scaling group of private worker nodes (2 initially, scales 2–4) that will run AutoCare pods. |
| `aws_iam_role.alb_controller` / `aws_iam_role.ebs_csi` | IRSA roles trusted only by the specific Kubernetes service account (`sub` claim) that needs them — the AWS Load Balancer Controller and the EBS CSI driver, respectively. |
| `aws_eks_addon.*` | Managed add-ons: `vpc-cni` (pod networking), `kube-proxy`, `coredns` (in-cluster DNS), and `aws-ebs-csi-driver` (persistent volume support), all upgraded by AWS instead of hand-managed manifests. |

> **Note on the AWS Load Balancer Controller itself:** this Terraform creates
> the IAM policy and IRSA role it needs, but the controller add-on/Helm
> release and Ingress resources belong to the Kubernetes manifests stage,
> which is intentionally out of scope here.

### RDS module (`modules/rds`)
| Resource | Purpose |
|---|---|
| `aws_db_subnet_group` | Pins RDS to the two private database subnets only. |
| `aws_security_group.rds` | Ingress limited to TCP/3306 from the EKS cluster security group ID passed in — nothing else can reach the database. |
| `aws_db_instance` | MySQL 8.0, `storage_encrypted = true`, Multi-AZ (configurable), automated backups with configurable retention, CloudWatch log exports (error/general/slowquery), Enhanced Monitoring, Performance Insights, and `manage_master_user_password = true` so the password lives only in AWS Secrets Manager. `deletion_protection` and `skip_final_snapshot` are both variables so dev can be torn down freely while prod is protected. |
| `aws_iam_role.rds_monitoring` | Lets RDS Enhanced Monitoring publish OS-level metrics to CloudWatch. |

### ECR module (`modules/ecr`)
| Resource | Purpose |
|---|---|
| `aws_ecr_repository` | Stores AutoCare container images; scan-on-push enabled, encrypted, immutable tags by default so a deployed tag can never be silently overwritten. |
| `aws_ecr_lifecycle_policy` | Expires untagged images after N days and keeps only the most recent N tagged images, so the registry doesn't grow unbounded. |

### Monitoring module (`modules/monitoring`)
| Resource | Purpose |
|---|---|
| `aws_flow_log` + `aws_cloudwatch_log_group.flow_logs` | Captures all accepted/rejected traffic in the VPC for security auditing and troubleshooting. |
| `aws_sns_topic.alarms` | Single notification channel for infrastructure alarms; subscribe an email via `alarm_sns_email`. |
| `aws_cloudwatch_metric_alarm.rds_*` | Alerts on RDS CPU, free storage, and connection count before they become incidents. |
| `aws_cloudwatch_metric_alarm.nat_error_port_allocation` | Warns if a NAT Gateway is running out of ports (a common silent failure mode under load). |

### Bootstrap (`bootstrap/`)
Creates the versioned, encrypted, public-access-blocked S3 bucket used as the
remote state backend for every environment. State **locking** uses
Terraform's native S3 conditional-write locking (`use_lockfile = true`,
Terraform ≥ 1.10) — this is the current AWS-recommended approach and requires
no DynamoDB table.

## 4. Prerequisites

- Terraform ≥ 1.10.0
- AWS CLI v2, configured with credentials that have sufficient permissions
  (VPC, EKS, RDS, ECR, IAM, CloudWatch, S3, SNS)
- `kubectl` (for interacting with the cluster once created)
- No AWS credentials or database passwords are ever hard-coded — the AWS
  provider uses your local credential chain (env vars, SSO profile, or an
  assumed role), and the DB password lives only in Secrets Manager.

## 5. One-time setup: remote state backend

```bash
cd terraform/bootstrap
terraform init
terraform apply
# Note the state_bucket_name output, e.g. autocare-terraform-state-123456789012
```

Then, for each environment:

```bash
cd terraform/environments/dev   # or prod
cp backend.hcl.example backend.hcl
# edit backend.hcl: set bucket = "<state_bucket_name from above>"
```

## 6. Terraform validation commands

Run these for `bootstrap/`, `environments/dev/`, and `environments/prod/`:

```bash
terraform fmt -recursive
terraform init -backend-config=backend.hcl   # omit -backend-config for bootstrap/
terraform validate
terraform plan -out=tfplan
```

## 7. Deployment workflow

```bash
cd terraform/environments/dev

# 1. Initialize with the remote backend
terraform init -backend-config=backend.hcl

# 2. Validate configuration
terraform validate

# 3. Review the plan
terraform plan -var-file=terraform.tfvars -out=tfplan

# 4. Apply
terraform apply tfplan

# 5. Configure kubectl (also printed as an output)
aws eks update-kubeconfig --region us-east-1 --name autocare-dev-eks

# 6. Verify
kubectl get nodes
```

Repeat under `terraform/environments/prod` for production, after editing
`terraform.tfvars` (especially `eks_public_access_cidrs`, which must be
restricted to real trusted CIDRs before applying).

### Destroying an environment

```bash
cd terraform/environments/dev
terraform plan -destroy -var-file=terraform.tfvars -out=tfplan.destroy
terraform apply tfplan.destroy
```

Production has `rds_deletion_protection = true` and `rds_skip_final_snapshot =
false` by default — RDS deletion protection must be turned off (via
`terraform apply` with the variable flipped, or in the console) before a
`terraform destroy` can succeed, which is intentional friction for a
production database.

## 8. Security summary

- No public subnets contain EKS nodes or RDS — only NAT Gateways and the
  future ALB live there.
- Security groups follow least privilege: RDS only accepts 3306 from the EKS
  cluster security group; nothing is open to `0.0.0.0/0` except the
  (optionally restricted) EKS public API endpoint.
- All EKS and RDS IAM roles are scoped to exactly the managed policies they
  need; Kubernetes workloads that need AWS access use IRSA, not node-wide
  credentials.
- Encryption at rest is enabled for RDS storage and the Terraform state
  bucket; ECR images are scanned on push.
- `deletion_protection`, `skip_final_snapshot`, and `multi_az` are all
  variables, defaulted safely for `prod` and relaxed for `dev`.
- VPC Flow Logs and EKS control-plane logs are shipped to CloudWatch for
  audit and incident response.

## 9. What's intentionally NOT included yet

- Kubernetes manifests/Helm values for the AutoCare Deployment, Service, and
  Ingress, or the AWS Load Balancer Controller Helm release itself.
- The Jenkins server and its pipeline definition.
- Route 53 hosted zone / DNS records (bring your own zone and point it at the
  ALB's DNS name once the Ingress is created).

These are deliberately left for the next stage of the AutoCare DevOps
pipeline: `GitHub → Jenkins → Maven → SonarQube → Docker → Amazon ECR →
Amazon EKS → AWS Load Balancer → AutoCare application → Amazon RDS MySQL`.
