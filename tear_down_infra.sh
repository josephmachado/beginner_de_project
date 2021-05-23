#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo 'Please enter your bucket name as ./spindown_infra.sh your-bucket'
    exit 0
fi

AWS_ID=$(aws sts get-caller-identity --query Account --output text | cat)
AWS_REGION=$(aws configure get region)

SERVICE_NAME=sde-batch-de-project
IAM_ROLE_NAME=sde-spectrum-redshift

echo "Deleting bucket "$1" and its contents"
aws s3 rm s3://$1 --recursive --output text >> tear_down.log
aws s3api delete-bucket --bucket $1 --output text >> tear_down.log

echo "Deleting local data"
rm -f data.zip
rm -rf data

echo "Spinning down local Airflow infrastructure"
docker compose down --volumes --rmi all

echo "Terminating EMR cluster "$SERVICE_NAME""
EMR_CLUSTER_ID=$(aws emr list-clusters --active --query 'Clusters[?Name==`'$SERVICE_NAME'`].Id' --output text)
aws emr terminate-clusters --cluster-ids $EMR_CLUSTER_ID >> tear_down.log

echo "Terminating Redshift cluster "$SERVICE_NAME""
aws redshift delete-cluster --skip-final-cluster-snapshot --cluster-identifier $SERVICE_NAME --output text >> tear_down.log

echo "Dissociating AmazonS3ReadOnlyAccess policy from "$IAM_ROLE_NAME" role"
aws iam detach-role-policy --role-name $IAM_ROLE_NAME  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --output text >> tear_down.log
echo "Dissociating AWSGlueConsoleFullAccess policy from "$IAM_ROLE_NAME" role"
aws iam detach-role-policy --role-name $IAM_ROLE_NAME  --policy-arn arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess --output text >> tear_down.log
echo "Deleting role"$IAM_ROLE_NAME""
aws iam delete-role --role-name $IAM_ROLE_NAME  --output text >> tear_down.log

rm -f tear_down.log setup.log trust-policy.json
