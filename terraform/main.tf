terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    redshift = {
      source  = "brainly/redshift"
      version = "1.0.2"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = var.aws_region
  profile = "default"
}

# Create our S3 bucket (Datalake)
resource "aws_s3_bucket" "sde-data-lake" {
  bucket_prefix = var.bucket_prefix
  force_destroy = true
}

resource "aws_s3_bucket_acl" "sde-data-lake-acl" {
  bucket = aws_s3_bucket.sde-data-lake.id
  acl    = "public-read-write"
}

# Create IAM role 

resource "aws_iam_role" "sde_ec2_iam_role" {
  name = "sde_ec2_iam_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3FullAccess", "arn:aws:iam::aws:policy/AmazonEMRFullAccessPolicy_v2", "arn:aws:iam::aws:policy/AmazonRedshiftAllCommandsFullAccess"]
}

resource "aws_iam_instance_profile" "sde_ec2_iam_role_instance_profile" {
  name = "sde_ec2_iam_role_instance_profile"
  role = aws_iam_role.sde_ec2_iam_role.name
}

resource "aws_iam_role" "sde_redshift_iam_role" {
  name = "sde_redshift_iam_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess", "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"]
}

# Create security group for access to EC2 from your Anywhere
resource "aws_security_group" "sde_security_group" {
  name        = "sde_security_group"
  description = "Security group to allow inbound SCP & outbound 8080 (Airflow) connections"

  ingress {
    description = "Inbound SCP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { # make this only 8080 TPC port
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { # make this only 8080 TPC port
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sde_security_group"
  }
}

#Set up EMR
resource "aws_emr_cluster" "sde_emr_cluster" {
  name                   = "sde_emr_cluster"
  release_label          = "emr-6.2.0"
  applications           = ["Spark", "Hadoop"]
  scale_down_behavior    = "TERMINATE_AT_TASK_COMPLETION"
  service_role           = "EMR_DefaultRole"
  termination_protection = false
  auto_termination_policy {
    idle_timeout = var.auto_termination_timeoff
  }

  ec2_attributes {
    instance_profile = aws_iam_instance_profile.sde_ec2_iam_role_instance_profile.id
  }


  master_instance_group {
    instance_type  = var.instance_type
    instance_count = 1
    name           = "Master - 1"

    ebs_config {
      size                 = 32
      type                 = "gp2"
      volumes_per_instance = 2
    }
  }

  core_instance_group {
    instance_type  = var.instance_type
    instance_count = 2
    name           = "Core - 2"

    ebs_config {
      size                 = "32"
      type                 = "gp2"
      volumes_per_instance = 2
    }
  }
}

# Set up Redshift
resource "aws_redshift_cluster" "sde_redshift_cluster" {
  cluster_identifier  = "sde-redshift-cluster"
  master_username     = "sde_user"
  master_password     = "sdeP0ssword0987"
  port                = 5439
  node_type           = "dc2.large"
  cluster_type        = "single-node"
  iam_roles           = [aws_iam_role.sde_redshift_iam_role.arn]
  skip_final_snapshot = true
}

# Create Redshift spectrum schema
provider "redshift" {
  host     = aws_redshift_cluster.sde_redshift_cluster.dns_name
  username = "sde_user"
  password = "sdeP0ssword0987"
  database = "dev"
}


# External schema using AWS Glue Data Catalog
resource "redshift_schema" "external_from_glue_data_catalog" {
  name  = "spectrum"
  owner = "sde_user"
  external_schema {
    database_name = "spectrum"
    data_catalog_source {
      region                                 = var.aws_region
      iam_role_arns                          = [aws_iam_role.sde_redshift_iam_role.arn]
      create_external_database_if_not_exists = true
    }
  }
}

# Create EC2 with IAM role to allow EMR, Redshift, & S3 access and security group 
resource "tls_private_key" "custom_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name_prefix = var.key_name
  public_key      = tls_private_key.custom_key.public_key_openssh
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20220420"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "sde_ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  key_name             = aws_key_pair.generated_key.key_name
  security_groups      = [aws_security_group.sde_security_group.name]
  iam_instance_profile = aws_iam_instance_profile.sde_ec2_iam_role_instance_profile.id
  tags = {
    Name = "sde_ec2"
  }

  user_data = <<EOF
#!/bin/bash

echo "-------------------------START DOCKER SETUP---------------------------"
sudo apt-get -y update

sudo apt-get -y install \
ca-certificates \
curl \
gnupg \
lsb-release

sudo apt -y install unzip

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get -y update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo chmod 666 /var/run/docker.sock

sudo apt install make

cd /home/ubuntu && git clone https://github.com/josephmachado/beginner_de_project.git && cd beginner_de_project && git checkout SDE-20221006-infra-setup-improvements && cd .. && sudo chmod -R u=rwx,g=rwx,o=rwx ./beginner_de_project 

cd beginner_de_project && echo "AIRFLOW_CONN_REDSHIFT=postgres://sde_user:sdeP0ssword0987@${aws_redshift_cluster.sde_redshift_cluster.endpoint}/dev" > env && echo "AIRFLOW_CONN_POSTGRES_DEFAULT=postgres://airflow:airflow@localhost:5439/airflow" >> env && echo "AIRFLOW_CONN_AWS_DEFAULT=aws://?region_name=${var.aws_region}" >> env && echo "AIRFLOW_VAR_EMR_ID=${aws_emr_cluster.sde_emr_cluster.id}" >> env && echo "AIRFLOW_VAR_BUCKET=${aws_s3_bucket.sde-data-lake.id}" >> env

echo "Spinning up the docker containers"
mkdir logs plugins temp && sudo chmod -R u=rwx,g=rwx,o=rwx logs plugins temp
cd /home/ubuntu/beginner_de_project && sleep 120 && sudo make up

echo "-------------------------END DOCKER SETUP---------------------------"

EOF

}

# Setting as budget monitor, so we don't go over 10USD per month
resource "aws_budgets_budget" "cost" {
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
}
