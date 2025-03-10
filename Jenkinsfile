pipeline {
    agent any

    environment {
        AWS_REGION = "us-east-1"
        ECR_REPO = "mlflow-model-repo"
        IMAGE_TAG = "latest"
        MLFLOW_TRACKING_URI = "http://${MLFLOW_SERVER_IP}:5000"
        TF_IN_AUTOMATION = "true"
        PATH = "/usr/local/bin:$PATH"
        PYTHONPATH = "/usr/local/lib/python3.8/site-packages:$PYTHONPATH"
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/JJGuilloryGit/mcmdonaws.git',
                    credentialsId: 'github-creds-id'
            }
        }

        stage('Setup Python Environment') {
            steps {
                sh """
                    python3 -m pip install --upgrade pip
                    python3 -m pip install --no-cache-dir mlflow pandas numpy scikit-learn
                """
            }
        }

        stage('Initialize Terraform') {
            steps {
                sh """
                    rm -rf .terraform
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
                    export PYTHONPATH=/usr/local/lib/python3.8/site-packages:$PYTHONPATH
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
            rm -f terraform.tfstate
            rm -f terraform.tfstate.backup
            rm -f .terraform.lock.hcl
        """
            cleanWs()
        }
        failure {
            script {
                if (fileExists('tfplan')) {
                    sh "rm tfplan"
                }
                sh "rm -rf .terraform"
            }
        }
        success {
            script {
                if (fileExists('tfplan')) {
                    sh "rm tfplan"
                }
                sh "rm -rf .terraform"
            }
        }
    }
}


