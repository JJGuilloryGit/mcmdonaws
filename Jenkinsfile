pipeline {
    agent any

    environment {
        AWS_REGION = "us-east-1"
        ECR_REPO = "mlflow-model-repo"
        IMAGE_TAG = "latest"
        MLFLOW_TRACKING_URI = "http://${MLFLOW_SERVER_IP}:5000"
        TF_IN_AUTOMATION = "true"
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/JJGuilloryGit/mcmdonaws.git',
                    credentialsId: 'github-creds-id'
            }
        }

        stage('Install Python Dependencies') {
            steps {
                sh """
                    apt-get update
                    apt-get install -y python3-pip
                    python3 -m pip install --upgrade pip
                    python3 -m pip install --no-cache-dir mlflow pandas numpy scikit-learn
                """
            }
        }

        stage('Clean Workspace') {
            steps {
                sh """
                    rm -rf .terraform
                    rm -f .terraform.lock.hcl
                """
            }
        }

        stage('Initialize Terraform') {
            steps {
                sh """
                    terraform init -upgrade
                """
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh """
                        terraform plan -out=tfplan
                    """
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh """
                        terraform apply -auto-approve tfplan
                    """
                }
            }
        }

        stage('Train Model & Log to MLflow') {
            steps {
                sh """
                    python3 train.py
                """
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    def ecrUrl = sh(
                        script: "terraform output -raw ecr_repository_url",
                        returnStdout: true
                    ).trim()
                    
                    sh """
                        docker build -t ${ecrUrl}:${IMAGE_TAG} .
                    """
                }
            }
        }

        stage('Push to AWS ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    script {
                        def ecrUrl = sh(
                            script: "terraform output -raw ecr_repository_url",
                            returnStdout: true
                        ).trim()
                        
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ecrUrl}
                            docker push ${ecrUrl}:${IMAGE_TAG}
                        """
                    }
                }
            }
        }

        stage('Update Kubernetes Config') {
            steps {
                script {
                    def ecrUrl = sh(
                        script: "terraform output -raw ecr_repository_url",
                        returnStdout: true
                    ).trim()
                    
                    sh """
                        sed -i 's|image:.*|image: ${ecrUrl}:${IMAGE_TAG}|' k8s_deployment.yaml
                    """
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh """
                        kubectl apply -f k8s_deployment.yaml
                    """
                }
            }
        }
    }

    post {
        always {
            sh """
                rm -rf .terraform
                rm -f .terraform.lock.hcl
                rm -f terraform.tfstate
                rm -f terraform.tfstate.backup
            """
            cleanWs()
        }
    }
}


