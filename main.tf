provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "awsaibucket1"
    key    = "state/terraform.tfstate"
    region = "us-east-1"
  }
}


# VPC and Networking
resource "aws_vpc" "mlflow_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "mlflow-vpc"
  }
}

# Create subnets in different AZs
resource "aws_subnet" "mlflow_subnet_1" {
  vpc_id            = aws_vpc.mlflow_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "mlflow-subnet-1"
  }
}

resource "aws_subnet" "mlflow_subnet_2" {
  vpc_id            = aws_vpc.mlflow_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "mlflow-subnet-2"
  }
}

# S3 bucket with valid name
resource "aws_s3_bucket" "mlflow_artifacts" {
  bucket = "mlflow-artifacts-bucket-${random_string.suffix.result}"
}

# Create random suffix for unique S3 bucket name
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# RDS subnet group with multiple AZs
resource "aws_db_subnet_group" "mlflow_subnet_group" {
  name        = "mlflow-db-subnet-group"
  description = "Subnet group for MLflow RDS instance"
  subnet_ids  = [aws_subnet.mlflow_subnet_1.id, aws_subnet.mlflow_subnet_2.id]

  tags = {
    Name = "MLflow DB subnet group"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "mlflow_igw" {
  vpc_id = aws_vpc.mlflow_vpc.id

  tags = {
    Name = "mlflow-igw"
  }
}

# Route Table
resource "aws_route_table" "mlflow_route_table" {
  vpc_id = aws_vpc.mlflow_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mlflow_igw.id
  }

  tags = {
    Name = "mlflow-route-table"
  }
}

# Route Table Association for both subnets
resource "aws_route_table_association" "subnet_1_association" {
  subnet_id      = aws_subnet.mlflow_subnet_1.id
  route_table_id = aws_route_table.mlflow_route_table.id
}

resource "aws_route_table_association" "subnet_2_association" {
  subnet_id      = aws_subnet.mlflow_subnet_2.id
  route_table_id = aws_route_table.mlflow_route_table.id
}

# ECR Repository
resource "aws_ecr_repository" "mlflow_model_repo" {
  name                 = "mlflow-model-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# IAM user for Jenkins
resource "aws_iam_user" "jenkins_user" {
  name = "jenkins-ecr-user"
}

# IAM policy for ECR access
resource "aws_iam_policy" "ecr_access_policy" {
  name        = "jenkins-ecr-access-policy"
  description = "Policy for Jenkins ECR access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerPart",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = [aws_ecr_repository.mlflow_model_repo.arn]
      },
      {
        Sid    = "ECRToken"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = ["*"]
      }
    ]
  })
}

# Attach policy to Jenkins user
resource "aws_iam_user_policy_attachment" "jenkins_ecr_policy" {
  user       = aws_iam_user.jenkins_user.name
  policy_arn = aws_iam_policy.ecr_access_policy.arn
}

# Create access key for Jenkins user
resource "aws_iam_access_key" "jenkins_user_key" {
  user = aws_iam_user.jenkins_user.name
}

# Outputs
output "ecr_repository_url" {
  value = aws_ecr_repository.mlflow_model_repo.repository_url
}

output "jenkins_access_key_id" {
  value     = aws_iam_access_key.jenkins_user_key.id
  sensitive = true
}

output "jenkins_secret_access_key" {
  value     = aws_iam_access_key.jenkins_user_key.secret
  sensitive = true
}

output "s3_bucket_name" {
  value = aws_s3_bucket.mlflow_artifacts.id
}
