#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo 'Please enter your bucket name as ./tear_down_infra.sh your-bucket'
    exit 0
fi

AWS_ID=$(aws sts get-caller-identity --query Account --output text | cat)

echo "Reading infrastructure variables from infra_variables.txt"
source infra_variables.txt

echo "Reading state values from state.log"
source state.log

echo "Deleting bucket "$1" and its contents"
aws s3 rm s3://$1 --recursive --output text >> tear_down.log
aws s3api delete-bucket --bucket $1 --output text >> tear_down.log

echo "Terminating EC2 instance"
aws ec2 terminate-instances --instance-ids $EC2_ID --region $AWS_REGION  >> tear_down.log

MY_IP=$(curl -s http://whatismyip.akamai.com/)

echo "Delete EC2 security group ingress"
aws ec2 revoke-security-group-ingress --group-id $EC2_SECURITY_GROUP_ID --protocol tcp --port 22 --cidr $MY_IP/24 --output text >> tear_down.log

echo "Delete EC2 security group ingress"
aws ec2 revoke-security-group-egress --group-id $EC2_SECURITY_GROUP_ID --protocol tcp --port 8080 --cidr $MY_IP/32 --output text >> tear_down.log

echo "Terminating EMR cluster "$SERVICE_NAME""
EMR_CLUSTER_ID=$(aws emr list-clusters --active --query 'Clusters[?Name==`'$SERVICE_NAME'`].Id' --output text)
aws emr terminate-clusters --cluster-ids $EMR_CLUSTER_ID >> tear_down.log

echo "Deleting EC2 security group"
sleep 60
aws ec2 delete-security-group --group-id $EC2_SECURITY_GROUP_ID --output text >> tear_down.log

echo "Terminating Redshift cluster "$SERVICE_NAME""
aws redshift delete-cluster --skip-final-cluster-snapshot --cluster-identifier $SERVICE_NAME --output text >> tear_down.log

echo "Dissociating AmazonS3ReadOnlyAccess policy from "$IAM_ROLE_NAME" role"
aws iam detach-role-policy --role-name $IAM_ROLE_NAME  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --output text >> tear_down.log
echo "Dissociating AWSGlueConsoleFullAccess policy from "$IAM_ROLE_NAME" role"
aws iam detach-role-policy --role-name $IAM_ROLE_NAME  --policy-arn arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess --output text >> tear_down.log
echo "Deleting role "$IAM_ROLE_NAME""
aws iam delete-role --role-name $IAM_ROLE_NAME  --output text >> tear_down.log

EC2_IAM_ROLE=sde-ec2-s3-emr-rs-access
echo "Remove role from instance profile"
aws iam remove-role-from-instance-profile --instance-profile-name $EC2_IAM_ROLE-instance-profile --role-name $EC2_IAM_ROLE --output text >> tear_down.log

echo "Deleting role instance profile "$EC2_IAM_ROLE"-instance-profile"
aws iam delete-instance-profile --instance-profile-name $EC2_IAM_ROLE-instance-profile --output text >> tear_down.log

echo "Dissociating AmazonS3FullAccess policy from "$EC2_IAM_ROLE" role"
aws iam detach-role-policy --role-name $EC2_IAM_ROLE  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --output text >> tear_down.log

echo "Dissociating AmazonEMRFullAccessPolicy_v2 policy from "$EC2_IAM_ROLE" role"
aws iam detach-role-policy --role-name $EC2_IAM_ROLE  --policy-arn arn:aws:iam::aws:policy/AmazonEMRFullAccessPolicy_v2 --output text >> tear_down.log

echo "Dissociating AmazonRedshiftAllCommandsFullAccess policy from "$EC2_IAM_ROLE" role"
aws iam detach-role-policy --role-name $EC2_IAM_ROLE  --policy-arn arn:aws:iam::aws:policy/AmazonRedshiftAllCommandsFullAccess --output text >> tear_down.log

echo "Deleting role "$EC2_IAM_ROLE""
aws iam delete-role --role-name $EC2_IAM_ROLE  --output text >> tear_down.log

echo "Deleting SSH key"
aws ec2 delete-key-pair --key-name sde-key --region $AWS_REGION >> setup.log
rm -f sde-key.pem

rm -f tear_down.log setup.log state.log trust-policy.json
