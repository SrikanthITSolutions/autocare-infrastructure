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
//   - "autocare-tf-state-bucket" Secret text credential holding the S3
//                               bucket name created by terraform/bootstrap
//                               (not sensitive, but kept out of source so
//                               the same Jenkinsfile works in any account).
//
// Agent requirements: terraform (>= 1.10.0), aws-cli v2, kubectl. Optionally
// tfsec for the security-scan stage (the pipeline skips it gracefully if
// tfsec is not installed).
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
        TF_STATE_BUCKET    = credentials('autocare-tf-state-bucket')
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
                    sh 'aws sts get-caller-identity'
                }
            }
        }

        stage('Terraform Init') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-autocare-creds']]) {
                    dir(env.TF_WORKING_DIR) {
                        sh """
                            terraform init \
                              -backend-config="bucket=${TF_STATE_BUCKET}" \
                              -backend-config="key=${params.ENVIRONMENT}/terraform.tfstate" \
                              -backend-config="region=${AWS_DEFAULT_REGION}" \
                              -backend-config="encrypt=true" \
                              -backend-config="use_lockfile=true"
                        """
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
