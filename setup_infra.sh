#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo 'Please enter your bucket name as ./setup_infra.sh your-bucket'
    exit 0
fi

# Check if docker is running; ref: https://stackoverflow.com/questions/43721513/how-to-check-if-the-docker-engine-and-a-docker-container-are-running
if ! docker info >/dev/null 2>&1; then
    echo "Docker does not seem to be running, run it first and retry"
    exit 1
fi

AWS_ID=$(aws sts get-caller-identity --query Account --output text | cat)
AWS_REGION=$(aws configure get region)

SERVICE_NAME=sde-batch-de-project
IAM_ROLE_NAME=sde-spectrum-redshift

REDSHIFT_USER=sde_user
REDSHIFT_PASSWORD=sdeP0ssword0987
REDSHIFT_PORT=5439
EMR_NODE_TYPE=m4.xlarge

echo "Creating bucket "$1""
aws s3api create-bucket --acl public-read-write --bucket $1 --output text >> setup.log

echo "Clean up stale local data"
rm -f data.zip
rm -rf data
echo "Download data"
aws s3 cp s3://start-data-engg/data.zip ./
unzip data.zip

echo "Spinning up local Airflow infrastructure"
rm -rf logs
mkdir logs
rm -rf temp
mkdir temp
docker compose up airflow-init
docker compose up -d
echo "Sleeping 5 Minutes to let Airflow containers reach a healthy state"
sleep 300

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


echo "Creating AWS IAM role"
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

echo "adding redshift connections to Airflow connection param"
docker exec -d beginner_de_project_airflow-webserver-1 airflow connections add 'redshift' --conn-type 'Postgres' --conn-login $REDSHIFT_USER --conn-password $REDSHIFT_PASSWORD --conn-host $REDSHIFT_HOST --conn-port $REDSHIFT_PORT --conn-schema 'dev'
docker exec -d beginner_de_project_airflow-webserver-1 airflow connections add 'postgres_default' --conn-type 'Postgres' --conn-login 'airflow' --conn-password 'airflow' --conn-host 'localhost' --conn-port 5432 --conn-schema 'airflow'

echo "adding S3 bucket name to Airflow variables"
docker exec -d beginner_de_project_airflow-webserver-1 airflow variables set BUCKET $1

echo "adding EMR ID to Airflow variables"
EMR_CLUSTER_ID=$(aws emr list-clusters --active --query 'Clusters[?Name==`'$SERVICE_NAME'`].Id' --output text)
docker exec -d beginner_de_project_airflow-webserver-1 airflow variables set EMR_ID $EMR_CLUSTER_ID

echo "Setting up AWS access for Airflow workers"
AWS_ID=$(aws configure get aws_access_key_id)
AWS_SECRET_KEY=$(aws configure get aws_secret_access_key)
AWS_REGION=$(aws configure get region)
docker exec -d beginner_de_project_airflow-webserver-1 airflow connections add 'aws_default' --conn-type 'aws' --conn-login $AWS_ID --conn-password $AWS_SECRET_KEY --conn-extra '{"region_name":"'$AWS_REGION'"}'

echo "Successfully setup local Airflow containers, S3 bucket "$1", EMR Cluster "$SERVICE_NAME", redshift cluster "$SERVICE_NAME", and added config to Airflow connections and variables"
