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
resource "aws_s3_bucket" "alande-data-lake" {
  bucket_prefix = var.bucket_prefix
  force_destroy = true
}

resource "aws_s3_bucket_acl" "alande-data-lake-acl" {
  bucket = aws_s3_bucket.alande-data-lake.id
  acl    = "public-read-write"
}

# EMR default Role
data "aws_iam_policy" "AmazonElasticMapReduceRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

resource "aws_iam_role_policy_attachment" "EMR_DefaultRole-attach" {
  role = "${aws_iam_role.EMR_DefaultRole.name}"
  policy_arn = "${data.aws_iam_policy.AmazonElasticMapReduceRole.arn}"
}

data "aws_iam_policy_document" "emr-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["elasticmapreduce.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "EMR_DefaultRole" {
	name = "EMR_DefaultRole"
	description = "EMR_DefaultRole created via Terraform"
	assume_role_policy = "${data.aws_iam_policy_document.emr-assume-role-policy.json}"
}


# IAM role for EC2 to connect to AWS Redshift, S3, & EMR
resource "aws_iam_role" "alande_ec2_iam_role" {
  name = "alande_ec2_iam_role"
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

resource "aws_iam_instance_profile" "alande_ec2_iam_role_instance_profile" {
  name = "alande_ec2_iam_role_instance_profile"
  role = aws_iam_role.alande_ec2_iam_role.name
}

# IAM role for Redshift to be able to read data from S3 via Spectrum
resource "aws_iam_role" "alande_redshift_iam_role" {
  name = "alande_redshift_iam_role"
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

resource "aws_default_security_group" "default" {
  vpc_id = aws_default_vpc.default.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.my_ip}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create security group for access to EC2 from your Anywhere
resource "aws_security_group" "alande_security_group" {
  vpc_id = aws_default_vpc.default.id
  name        = "alande_security_group"
  description = "Security group to allow inbound SCP & outbound 8080 (Airflow) connections"

  ingress {
    description = "Inbound SCP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alande_security_group"
  }
}

resource "aws_security_group" "redshift_security_group" {
  vpc_id = aws_default_vpc.default.id
  name        = "redshift_security_group"
  ingress {
    from_port        = 5432
    to_port          = 5432
    security_groups  = [aws_security_group.alande_security_group.id]
    protocol         = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "redshift_security_group"
  }
}




#Set up EMR
resource "aws_emr_cluster" "alande_emr_cluster" {
  name                   = "alande_emr_cluster"
  release_label          = "emr-6.2.0"
  applications           = ["Spark", "Hadoop"]
  scale_down_behavior    = "TERMINATE_AT_TASK_COMPLETION"
  service_role           = "EMR_DefaultRole"
  termination_protection = false
  auto_termination_policy {
    idle_timeout = var.auto_termination_timeoff
  }


  ec2_attributes {
    subnet_id                         = aws_subnet.public_1.id
    instance_profile = aws_iam_instance_profile.alande_ec2_iam_role_instance_profile.id
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
resource "aws_redshift_cluster" "alande_redshift_cluster" {
  cluster_identifier  = "alande-redshift-cluster"
  master_username     = var.redshift_user
  master_password     = var.redshift_password
  port                = 5439
  node_type           = var.redshift_node_type
  cluster_type        = "single-node"
  iam_roles           = [aws_iam_role.alande_redshift_iam_role.arn]
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.redshift_security_group.id, aws_default_security_group.default.id]
}

# Create Redshift spectrum schema
provider "redshift" {
  host     = aws_redshift_cluster.alande_redshift_cluster.dns_name
  username = var.redshift_user
  password = var.redshift_password
  database = "dev"
}

# External schema using AWS Glue Data Catalog
resource "redshift_schema" "external_from_glue_data_catalog" {
  name  = "spectrum"
  owner = var.redshift_user
  external_schema {
    database_name = "spectrum"
    data_catalog_source {
      region                                 = var.aws_region
      iam_role_arns                          = [aws_iam_role.alande_redshift_iam_role.arn]
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

resource "aws_instance" "alande_ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.public_1.id
  key_name             = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.alande_security_group.id]
  iam_instance_profile = aws_iam_instance_profile.alande_ec2_iam_role_instance_profile.id
  tags = {
    Name = "alande_ec2"
  }

  user_data = <<EOF
#!/bin/bash

echo "-------------------------START AIRFLOW SETUP---------------------------"
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

echo 'Clone git repo to EC2'
cd /home/ubuntu && git clone https://github.com/a8356555/ecommerce-data-batch-processing-pipeline.git && cd ecommerce-data-batch-processing-pipeline && make perms

echo 'Setup Airflow environment variables'
echo "
AIRFLOW_CONN_REDSHIFT=postgres://${var.redshift_user}:${var.redshift_password}@${aws_redshift_cluster.alande_redshift_cluster.endpoint}/dev
AIRFLOW_CONN_POSTGRES_DEFAULT=postgres://airflow:airflow@localhost:5439/airflow
AIRFLOW_CONN_AWS_DEFAULT=aws://?region_name=${var.aws_region}
AIRFLOW_VAR_EMR_ID=${aws_emr_cluster.alande_emr_cluster.id}
AIRFLOW_VAR_BUCKET=${aws_s3_bucket.alande-data-lake.id}
" > env

echo 'Start Airflow containers'
make up

echo "-------------------------END AIRFLOW SETUP---------------------------"

EOF

}

# Setting as budget monitor, so we don't go over 10 USD per month
resource "aws_budgets_budget" "cost" {
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
}

resource "aws_default_vpc" "default" {}


resource "aws_subnet" "public_1" {
  vpc_id            = aws_default_vpc.default.id
  cidr_block = cidrsubnet(aws_default_vpc.default.cidr_block, 8, 0)
  map_public_ip_on_launch = true

  tags = {
    Name = "alande-public-subnet"
  }
}

resource "aws_internet_gateway" "alande" {
  vpc_id            = aws_default_vpc.default.id

  tags = {
    Name = "igw"
  }
}

resource "aws_route_table" "public" {
    vpc_id = aws_default_vpc.default.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.alande.id
    }

    tags = {
        Name = "public-rt"
    }
}

resource "aws_route_table_association" "public_1" {
    subnet_id = aws_subnet.public_1.id
    route_table_id = aws_route_table.public.id
}




# resource "aws_iam_service_linked_role" "es" {
#   aws_service_name = "es.amazonaws.com"
# }

# data "aws_caller_identity" "current" {}

# # setup elasticsearch
# resource "aws_elasticsearch_domain" "es" {
#   domain_name           = var.es_domain
#   elasticsearch_version = "6.3"

#   cluster_config {
#     instance_count         = 3
#     instance_type          = "m4.large.elasticsearch"
#     zone_awareness_enabled = false
#   }

#   vpc_options {
#       subnet_ids = [
#         aws_subnet.public_1.id
#       ]

#       security_group_ids = [
#           aws_security_group.alande_security_group.id
#       ]
#   }

#   access_policies = <<CONFIG
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Action": "es:*",
#             "Principal": "*",
#             "Effect": "Allow",
#             "Resource": "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/${var.es_domain}/*"
#         }
#     ]
# }
# CONFIG

#   ebs_options {
#       ebs_enabled = true
#       volume_size = 10
#   }

#   tags = {
#     Domain = "TestDomain"
#   }

#   depends_on = [aws_iam_service_linked_role.es]
# }
