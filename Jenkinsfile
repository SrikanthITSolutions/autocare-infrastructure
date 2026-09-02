// ---------------------------------------------------------------------------
// AutoCare - AWS Infrastructure Pipeline
//
// Provisions/updates/destroys the Terraform-managed AWS foundation
// (VPC, EKS, RDS, ECR, IAM, monitoring) defined under terraform/environments.
// This pipeline manages INFRASTRUCTURE ONLY. The application build/deploy
// pipeline (Maven -> SonarQube -> Docker -> ECR -> EKS) is a separate job
// that runs after this infrastructure already exists.
//
// Required Jenkins plugins:
//   - Pipeline: AWS Steps (credentials binding)
//   - Pipeline: Input Step
//   - AnsiColor
//   - Credentials Binding
//
// Required Jenkins credentials (Manage Jenkins > Credentials):
//   - "aws-autocare-creds"      AWS credentials (Access key/secret or an
//                               assumed-role profile) with permissions to
//                               manage VPC/EKS/RDS/ECR/IAM/CloudWatch/S3/SNS.
//                               NEVER hard-code these - this is the only
//                               place AWS access is granted to the pipeline.
//
// The remote state S3 bucket (autocare-terraform-state-<account-id>) needs
// no separate credential or manual bootstrap step - the "Ensure Remote
// State Backend" stage below creates it automatically on first run (via
// plain AWS CLI calls, since Terraform can't create the bucket it stores
// its own state in). terraform/bootstrap/ still exists as an optional
// pure-Terraform alternative for anyone bootstrapping outside Jenkins.
//
// Agent requirements: terraform (>= 1.10.0), aws-cli v2, kubectl, helm v3.
// Optionally tfsec for the security-scan stage (the pipeline skips it
// gracefully if tfsec is not installed).
//
// After a successful apply, this pipeline also installs the cluster-level
// software the autocare-deployment Helm chart depends on (AWS Load Balancer
// Controller, Secrets Store CSI Driver + AWS provider, Metrics Server) via
// helm/kubectl - so "terraform apply" plus this one Jenkins job is the
// entire, no-manual-steps path from empty AWS account to an EKS cluster
// ready for the application to be deployed onto.
// ---------------------------------------------------------------------------

pipeline {
    agent any

    options {
        timestamps()
        ansiColor('xterm')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '30'))
    }

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'prod'],
            description: 'Which terraform/environments/<name> to operate on'
        )
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Terraform action to run'
        )
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Skip the manual approval gate. Only honored for ACTION=apply on ENVIRONMENT=dev; ignored for prod and for destroy.'
        )
        string(
            name: 'CONFIRM_DESTROY',
            defaultValue: '',
            description: 'Required only when ACTION=destroy. Must exactly equal "destroy-<ENVIRONMENT>", e.g. destroy-dev.'
        )
    }

    environment {
        TF_IN_AUTOMATION   = 'true'
        TF_INPUT           = 'false'
        AWS_DEFAULT_REGION = 'us-east-1'
        TF_WORKING_DIR     = "terraform/environments/${params.ENVIRONMENT}"
        TF_STATE_KEY       = "${params.ENVIRONMENT}/terraform.tfstate"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Guard: Destroy Confirmation') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                script {
                    def expected = "destroy-${params.ENVIRONMENT}"
                    if (params.CONFIRM_DESTROY != expected) {
                        error("CONFIRM_DESTROY must exactly equal '${expected}' to run a destroy against ${params.ENVIRONMENT}. Aborting for safety.")
                    }
                }
            }
        }

        stage('Tool Versions') {
            steps {
                dir(env.TF_WORKING_DIR) {
                    sh '''
                        terraform -version
                        aws --version
                    '''
                }
            }
        }

        stage('Terraform Format Check') {
            steps {
                dir(env.TF_WORKING_DIR) {
                    sh 'terraform fmt -check -recursive -diff'
                }
            }
        }

        stage('AWS Identity Check') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-autocare-creds']]) {
                    script {
                        env.AWS_ACCOUNT_ID = sh(
                            script: 'aws sts get-caller-identity --query Account --output text',
                            returnStdout: true
                        ).trim()
                        env.TF_STATE_BUCKET = "autocare-terraform-state-${env.AWS_ACCOUNT_ID}"
                    }
                    sh 'aws sts get-caller-identity'
                }
            }
        }

        stage('Ensure Remote State Backend') {
            // Creates the S3 state bucket on first run if it doesn't exist yet -
            // no separate manual "terraform/bootstrap apply" step required.
            // Idempotent: safe to run on every build.
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-autocare-creds']]) {
                    sh '''
                        if aws s3api head-bucket --bucket "$TF_STATE_BUCKET" 2>/dev/null; then
                            echo "State bucket $TF_STATE_BUCKET already exists"
                        else
                            echo "Creating state bucket $TF_STATE_BUCKET"
                            if [ "$AWS_DEFAULT_REGION" = "us-east-1" ]; then
                                aws s3api create-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_DEFAULT_REGION"
                            else
                                aws s3api create-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_DEFAULT_REGION" \
                                    --create-bucket-configuration LocationConstraint="$AWS_DEFAULT_REGION"
                            fi
                            aws s3api put-bucket-versioning --bucket "$TF_STATE_BUCKET" \
                                --versioning-configuration Status=Enabled
                            aws s3api put-bucket-encryption --bucket "$TF_STATE_BUCKET" \
                                --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
                            aws s3api put-public-access-block --bucket "$TF_STATE_BUCKET" \
                                --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
                            aws s3api put-bucket-lifecycle-configuration --bucket "$TF_STATE_BUCKET" \
                                --lifecycle-configuration '{"Rules":[{"ID":"expire-old-state-versions","Status":"Enabled","Filter":{},"NoncurrentVersionExpiration":{"NoncurrentDays":90}}]}'
                        fi
                    '''
                }
            }
        }

        stage('Terraform Init') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-autocare-creds']]) {
                    dir(env.TF_WORKING_DIR) {
                        sh '''
                            terraform init \
                              -backend-config="bucket=$TF_STATE_BUCKET" \
                              -backend-config="key=$TF_STATE_KEY" \
                              -backend-config="region=$AWS_DEFAULT_REGION" \
                              -backend-config="encrypt=true" \
                              -backend-config="use_lockfile=true"
                        '''
                    }
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir(env.TF_WORKING_DIR) {
                    sh 'terraform validate'
                }
            }
        }

        stage('Security Scan (tfsec)') {
            steps {
                dir(env.TF_WORKING_DIR) {
                    sh '''
                        if command -v tfsec >/dev/null 2>&1; then
                            tfsec . --soft-fail
                        else
                            echo "tfsec not installed on this agent - skipping security scan"
                        fi
                    '''
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-autocare-creds']]) {
                    dir(env.TF_WORKING_DIR) {
                        script {
                            if (params.ACTION == 'destroy') {
                                sh 'terraform plan -destroy -var-file=terraform.tfvars -out=tfplan -input=false'
                            } else {
                                sh 'terraform plan -var-file=terraform.tfvars -out=tfplan -input=false'
                            }
                        }
                        sh 'terraform show -no-color tfplan > tfplan.txt'
                    }
                }
            }
        }

        stage('Publish Plan') {
            steps {
                dir(env.TF_WORKING_DIR) {
                    archiveArtifacts artifacts: 'tfplan, tfplan.txt', fingerprint: true
                }
            }
        }

        stage('Manual Approval') {
            when {
                allOf {
                    expression { params.ACTION != 'plan' }
                    expression { !(params.ACTION == 'apply' && params.ENVIRONMENT == 'dev' && params.AUTO_APPROVE) }
                }
            }
            steps {
                script {
                    def approver = input(
                        message: "Review the archived tfplan.txt, then approve Terraform ${params.ACTION.toUpperCase()} on ${params.ENVIRONMENT}?",
                        submitterParameter: 'APPROVED_BY'
                    )
                    echo "Approved by: ${approver}"
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-autocare-creds']]) {
                    dir(env.TF_WORKING_DIR) {
                        sh 'terraform apply -input=false tfplan'
                    }
                }
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-autocare-creds']]) {
                    dir(env.TF_WORKING_DIR) {
                        sh 'terraform apply -input=false tfplan'
                    }
                }
            }
        }

        stage('Capture Outputs') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir(env.TF_WORKING_DIR) {
                    sh 'terraform output -json > tf-outputs.json'
                    archiveArtifacts artifacts: 'tf-outputs.json', fingerprint: true
                }
            }
        }

        stage('Post-Apply Sanity Check') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-autocare-creds']]) {
                    dir(env.TF_WORKING_DIR) {
                        sh '''
                            CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
                            aws eks update-kubeconfig --region "$AWS_DEFAULT_REGION" --name "$CLUSTER_NAME"
                            kubectl get nodes
                        '''
                    }
                }
            }
        }

        stage('Install Cluster Add-ons') {
            // Installs the cluster-level software the AutoCare Helm chart
            // (autocare-deployment repo) depends on. Idempotent - safe to
            // re-run on every apply via `helm upgrade --install`.
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-autocare-creds']]) {
                    dir(env.TF_WORKING_DIR) {
                        sh '''
                            CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
                            VPC_ID=$(terraform output -raw vpc_id)
                            ALB_ROLE_ARN=$(terraform output -raw alb_controller_role_arn)
                            NAMESPACE=$(terraform output -raw ssm_parameter_path | sed 's#.*/##')

                            helm repo add eks https://aws.github.io/eks-charts
                            helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
                            helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
                            helm repo update

                            echo "==> AWS Load Balancer Controller"
                            helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
                              --namespace kube-system \
                              --set clusterName="${CLUSTER_NAME}" \
                              --set region="${AWS_DEFAULT_REGION}" \
                              --set vpcId="${VPC_ID}" \
                              --set serviceAccount.create=true \
                              --set serviceAccount.name=aws-load-balancer-controller \
                              --set serviceAccount.annotations."eks\\.amazonaws\\.com/role-arn"="${ALB_ROLE_ARN}" \
                              --wait --timeout 5m

                            echo "==> Secrets Store CSI Driver"
                            helm upgrade --install secrets-store-csi-driver secrets-store-csi-driver/secrets-store-csi-driver \
                              --namespace kube-system \
                              --set syncSecret.enabled=true \
                              --wait --timeout 5m

                            echo "==> Secrets Store CSI Driver - AWS provider (ASCP)"
                            kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml

                            echo "==> Metrics Server (required for HPA)"
                            helm upgrade --install metrics-server metrics-server/metrics-server \
                              --namespace kube-system \
                              --wait --timeout 5m

                            echo "==> Application namespace"
                            kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            dir(env.TF_WORKING_DIR) {
                archiveArtifacts artifacts: '*.log', allowEmptyArchive: true
            }
        }
        success {
            echo "Terraform ${params.ACTION} completed successfully for ${params.ENVIRONMENT}."
        }
        failure {
            echo "Terraform ${params.ACTION} failed for ${params.ENVIRONMENT}. Check the console output and archived tfplan.txt."
        }
        cleanup {
            cleanWs()
        }
    }
}
