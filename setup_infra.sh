#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo 'Please enter your bucket name as ./setup_infra.sh your-bucket'
    exit 0
fi

# check if AWS is installed and configured
# check if psql is installed

AWS_ID=$(aws sts get-caller-identity --query Account --output text | cat)
AWS_EC2_INSTANCE_NAME=sde-airflow-pg-$(openssl rand -base64 12)

echo "Reading infrastructure variables from infra_variables.txt"
source infra_variables.txt

echo "Creating bucket "$1""
aws s3api create-bucket --acl public-read-write --region $AWS_REGION --bucket $1 --output text >> setup.log

echo '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}' > ./trust-policy.json


echo "Creating AWS IAM role for EC2 S3 access"
aws iam create-role --role-name $EC2_IAM_ROLE --assume-role-policy-document file://trust-policy.json --description 'EC2 access to S3' --output text >> setup.log

echo "Attaching AmazonS3FullAccess Policy to the previous IAM role"
aws iam attach-role-policy --role-name $EC2_IAM_ROLE --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --output text >> setup.log

echo "Attaching AmazonEMRFullAccessPolicy_v2 Policy to the previous IAM role"
aws iam attach-role-policy --role-name $EC2_IAM_ROLE --policy-arn arn:aws:iam::aws:policy/AmazonEMRFullAccessPolicy_v2 --output text >> setup.log

echo "Attaching AmazonRedshiftAllCommandsFullAccess Policy to the previous IAM role"
aws iam attach-role-policy --role-name $EC2_IAM_ROLE --policy-arn arn:aws:iam::aws:policy/AmazonRedshiftAllCommandsFullAccess --output text >> setup.log

echo 'Creating IAM instance profile to add to EC2'
aws iam create-instance-profile --instance-profile-name $EC2_IAM_ROLE-instance-profile --output text >> setup.log
aws iam add-role-to-instance-profile --role-name $EC2_IAM_ROLE --instance-profile-name $EC2_IAM_ROLE-instance-profile --output text >> setup.log

echo "Creating ssh key to connect to EC2 instance"
aws ec2 create-key-pair --key-name sde-key --query "KeyMaterial" --output text --region $AWS_REGION > sde-key.pem
chmod 400 sde-key.pem

MY_IP=$(curl -s http://whatismyip.akamai.com/)

echo "Creating EC2 security group to only allow access from your IP $MY_IP"
EC2_SECURITY_GROUP_ID=$(aws ec2 create-security-group --description "Security group to allow inbound SCP connection" --group-name $EC2_SECURITY_GROUP --output text)
echo 'EC2_SECURITY_GROUP_ID="'$EC2_SECURITY_GROUP_ID'"' >> state.log

echo "Add inbound rule to allow ssh from IP $MY_IP"
aws ec2 authorize-security-group-ingress --group-id $EC2_SECURITY_GROUP_ID --protocol tcp --port 22 --cidr $MY_IP/24 --output text >> setup.log

echo "Add outbound rule to allow our IP $MY_IP to connect to EC2's 8080 port"
aws ec2 authorize-security-group-egress --group-id $EC2_SECURITY_GROUP_ID --protocol tcp --port 8080 --cidr $MY_IP/32 --output text >> setup.log

echo "Creating EC2 instance"
sleep 5
aws ec2 run-instances --image-id $EC2_IMAGE_ID --instance-type $AWS_EC2_INSTANCE --count 1 --key-name sde-key --user-data file://setup_ubuntu_docker.txt --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value='$AWS_EC2_INSTANCE_NAME'}]' --region $AWS_REGION >> setup.log

echo "Get EC2 ID"
sleep 20
EC2_ID=$(aws --region $AWS_REGION ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=$AWS_EC2_INSTANCE_NAME" --query 'Reservations[*].Instances[*].[InstanceId]' --output text)
echo "EC2 ID is $EC2_ID"
echo 'EC2_ID="'$EC2_ID'"' >> state.log

echo "Add security group to EC2"
aws ec2 modify-instance-attribute --instance-id $EC2_ID --groups $EC2_SECURITY_GROUP_ID --output text >> setup.log

while :
do
   echo "Waiting for EC2 instance to start, sleeping for 60s before next check"
   sleep 60
   EC2_STATUS=$(aws ec2 describe-instance-status --instance-ids $EC2_ID --query 'InstanceStatuses[0].InstanceState.Name' --output text)
   if [[ "$EC2_STATUS" == "running" ]]
   then
	break
   fi
done

echo "Attach "$EC2_IAM_ROLE"-instance-profile to EC2 instance"
aws ec2 associate-iam-instance-profile --instance-id $EC2_ID --iam-instance-profile Name=$EC2_IAM_ROLE-instance-profile --output text >> setup.log

echo "Get EC2 IPV4"
sleep 20
EC2_IPV4=$(aws --region $AWS_REGION ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=instance-id,Values=$EC2_ID" --query 'Reservations[*].Instances[*].[PublicDnsName]' --output text)
echo "EC2 IPV4 is $EC2_IPV4"

echo "SCP to copy code to remote server"
cd ../
scp -o "IdentitiesOnly yes" -i ./beginner_de_project/sde-key.pem -r ./beginner_de_project ubuntu@$EC2_IPV4:/home/ubuntu/beginner_de_project
cd beginner_de_project

echo "Clean up stale data"
sleep 10
ssh -o "IdentitiesOnly yes" -i "sde-key.pem" ubuntu@$EC2_IPV4 'cd beginner_de_project && rm -f data.zip && rm -rf data'

echo "Download data"
sleep 10
ssh -o "IdentitiesOnly yes" -i "sde-key.pem" ubuntu@$EC2_IPV4 'cd beginner_de_project && wget https://start-data-engg.s3.amazonaws.com/data.zip && sudo unzip data.zip && sudo chmod 755 data'

echo "Recreate logs and temp dir"
sleep 10
ssh -o "IdentitiesOnly yes" -i "sde-key.pem" ubuntu@$EC2_IPV4 'cd beginner_de_project && rm -rf logs && mkdir logs && rm -rf temp && mkdir temp && chmod 777 temp'

echo "Creating an AWS EMR Cluster named "$SERVICE_NAME""
aws emr create-default-roles >> setup.log
aws emr create-cluster --applications Name=Hadoop Name=Spark --release-label emr-6.2.0 --name $SERVICE_NAME --scale-down-behavior TERMINATE_AT_TASK_COMPLETION  --service-role EMR_DefaultRole --instance-groups '[
    {
        "InstanceCount": 1,
        "EbsConfiguration": {
            "EbsBlockDeviceConfigs": [
                {
                    "VolumeSpecification": {
                        "SizeInGB": 32,
                        "VolumeType": "gp2"
                    },
                    "VolumesPerInstance": 2
                }
            ]
        },
        "InstanceGroupType": "MASTER",
        "InstanceType": "'$EMR_NODE_TYPE'",
        "Name": "Master - 1"
    },
    {
        "InstanceCount": 2,
        "BidPrice": "OnDemandPrice",
        "EbsConfiguration": {
            "EbsBlockDeviceConfigs": [
                {
                    "VolumeSpecification": {
                        "SizeInGB": 32,
                        "VolumeType": "gp2"
                    },
                    "VolumesPerInstance": 2
                }
            ]
        },
        "InstanceGroupType": "CORE",
        "InstanceType": "'$EMR_NODE_TYPE'",
        "Name": "Core - 2"
    }
        ]' >> setup.log

echo '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "redshift.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}' > ./trust-policy.json


echo "Creating AWS IAM role for redshift spectrum S3 access"
aws iam create-role --role-name $IAM_ROLE_NAME --assume-role-policy-document file://trust-policy.json --description 'spectrum access for redshift' >> setup.log

echo "Attaching AmazonS3ReadOnlyAccess Policy to our IAM role"
aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --output text >> setup.log
echo "Attaching AWSGlueConsoleFullAccess Policy to our IAM role"
aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess --output text >> setup.log

echo "Creating an AWS Redshift Cluster named "$SERVICE_NAME""
aws redshift create-cluster --cluster-identifier $SERVICE_NAME --node-type dc2.large --master-username $REDSHIFT_USER --master-user-password $REDSHIFT_PASSWORD --cluster-type single-node --publicly-accessible --iam-roles "arn:aws:iam::"$AWS_ID":role/"$IAM_ROLE_NAME"" >> setup.log

while :
do
   echo "Waiting for Redshift cluster "$SERVICE_NAME" to start, sleeping for 60s before next check"
   sleep 60
   REDSHIFT_CLUSTER_STATUS=$(aws redshift describe-clusters --cluster-identifier $SERVICE_NAME --query 'Clusters[0].ClusterStatus' --output text)
   if [[ "$REDSHIFT_CLUSTER_STATUS" == "available" ]]
   then
	break
   fi
done

REDSHIFT_HOST=$(aws redshift describe-clusters --cluster-identifier $SERVICE_NAME --query 'Clusters[0].Endpoint.Address' --output text)

# TODO read the script from sql file
echo "Running setup script on redshift"
echo "CREATE EXTERNAL SCHEMA spectrum
FROM DATA CATALOG DATABASE 'spectrumdb' iam_role 'arn:aws:iam::"$AWS_ID":role/"$IAM_ROLE_NAME"' CREATE EXTERNAL DATABASE IF NOT EXISTS;
DROP TABLE IF EXISTS spectrum.user_purchase_staging;
CREATE EXTERNAL TABLE spectrum.user_purchase_staging (
    InvoiceNo VARCHAR(10),
    StockCode VARCHAR(20),
    detail VARCHAR(1000),
    Quantity INTEGER,
    InvoiceDate TIMESTAMP,
    UnitPrice DECIMAL(8, 3),
    customerid INTEGER,
    Country VARCHAR(20)
) PARTITIONED BY (insert_date DATE) 
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' 
STORED AS textfile 
LOCATION 's3://"$1"/stage/user_purchase/' 
TABLE PROPERTIES ('skip.header.line.count' = '1');
DROP TABLE IF EXISTS spectrum.classified_movie_review;
CREATE EXTERNAL TABLE spectrum.classified_movie_review (
    cid VARCHAR(100),
    positive_review boolean,
    insert_date VARCHAR(12)
) STORED AS PARQUET LOCATION 's3://"$1"/stage/movie_review/';
DROP TABLE IF EXISTS public.user_behavior_metric;
CREATE TABLE public.user_behavior_metric (
    customerid INTEGER,
    amount_spent DECIMAL(18, 5),
    review_score INTEGER,
    review_count INTEGER,
    insert_date DATE
);" > ./redshift_setup.sql

psql -f ./redshift_setup.sql postgres://$REDSHIFT_USER:$REDSHIFT_PASSWORD@$REDSHIFT_HOST:$REDSHIFT_PORT/dev
rm ./redshift_setup.sql

echo "Spinning up remote Airflow docker containers"
sleep 60
ssh -o "IdentitiesOnly yes" -i "sde-key.pem" ubuntu@$EC2_IPV4 'cd beginner_de_project && echo -e "AIRFLOW_UID=$(id -u)\nAIRFLOW_GID=0" > .env && docker compose up airflow-init && docker compose up --build -d'

echo "Sleeping 5 Minutes to let Airflow containers reach a healthy state"
sleep 300

echo "adding redshift connections to Airflow connection param"
ssh -o "IdentitiesOnly yes" -i "sde-key.pem" ubuntu@$EC2_IPV4 "docker exec -d webserver airflow connections add 'redshift' --conn-type 'Postgres' --conn-login $REDSHIFT_USER --conn-password $REDSHIFT_PASSWORD --conn-host $REDSHIFT_HOST --conn-port $REDSHIFT_PORT --conn-schema 'dev'"

echo "adding postgres connections to Airflow connection param"
ssh -o "IdentitiesOnly yes" -i "sde-key.pem" ubuntu@$EC2_IPV4 "docker exec -d webserver airflow connections add 'postgres_default' --conn-type 'Postgres' --conn-login 'airflow' --conn-password 'airflow' --conn-host 'localhost' --conn-port 5432 --conn-schema 'airflow'"

echo "adding S3 bucket name to Airflow variables"
ssh -o "IdentitiesOnly yes" -i "sde-key.pem" ubuntu@$EC2_IPV4 "docker exec -d webserver airflow variables set BUCKET $1"

echo "adding EMR ID to Airflow variables"
EMR_CLUSTER_ID=$(aws emr list-clusters --active --query 'Clusters[?Name==`'$SERVICE_NAME'`].Id' --output text)
ssh -o "IdentitiesOnly yes" -i "sde-key.pem" ubuntu@$EC2_IPV4 "docker exec -d webserver airflow variables set EMR_ID $EMR_CLUSTER_ID"

echo "set Airflow AWS region to "$AWS_REGION""
ssh -o "IdentitiesOnly yes" -i "sde-key.pem" ubuntu@$EC2_IPV4 "docker exec -d webserver airflow connections add 'aws_default' --conn-type 'aws' --conn-extra '{\"region_name\":\"'$AWS_REGION'\"}'"

echo "Successfully setup local Airflow containers, S3 bucket "$1", EMR Cluster "$SERVICE_NAME", redshift cluster "$SERVICE_NAME", and added config to Airflow connections and variables"

echo "Forwardin Metabase port to http://localhost:3000"
ssh -o "IdentitiesOnly yes" -i "sde-key.pem" ubuntu@$EC2_IPV4 -N -f -L 3000:$EC2_IPV4:3000

echo "Opening Airflow UI ..."
sleep 60
ssh -o "IdentitiesOnly yes" -i "sde-key.pem" ubuntu@$EC2_IPV4 -N -f -L 8080:$EC2_IPV4:8080
open http://localhost:8080
