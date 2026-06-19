#!/bin/bash
##############################################################################
# Module-05
# This assignment requires you to modify your previous scripts and use the 
# Launch Template and Autoscaling group commands for creating EC2 instances
# You will need an additional script to generate a JSON file with parameters
# for your launch template. You will need to add an extras storage harddisk (EBS)
# to each EC2 instance, define and IAM profile to use and define the name of two
# S3 buckets to create
# 
# You will need to define these variables in a txt file named: arguments.txt
# 1 image-id
# 2 instance-type
# 3 key-name
# 4 security-group-ids
# 5 count
# 6 user-data file name
# 7 Tag (use the module name - later we can use the tags to query/filter
# 8 Target Group (use your initials)
# 9 elb-name (use your initials)
# 10 Availability Zone 1
# 11 Availability Zone 2
# 12 Launch Template Name
# 13 ASG name
# 14 ASG min
# 15 ASG max
# 16 ASG desired
# 17 AWS Region for LaunchTemplate (use your default region)
# 18 EBS disk storage size in GB
# 19 S3 Bucket One
# 20 S3 Bucket Two
##############################################################################

#!/bin/bash

ltconfigfile="./config.json"

if [ $# -ne 20 ]
then
  echo "You don't have enough variables in your arguments.txt, perhaps you forgot to run: bash ./create-env.sh \$(< ~/arguments.txt)"
  exit 1
elif ! [[ -a "$ltconfigfile" ]]
then
  echo "The launch template configuration JSON file doesn't exist - run: bash ./create-lt-json.sh \$(< ~/arguments.txt)"
  exit 1
else
  echo "Launch template data file: $ltconfigfile exists..."

  echo "Finding and storing default VPCID value..."
  VPCID=$(aws ec2 describe-vpcs \
    --filters "Name=is-default,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text)
  echo "$VPCID"

  echo "Finding subnet IDs for Availability Zone 1 and 2..."
  SUBNET2A=$(aws ec2 describe-subnets \
    --output text \
    --query 'Subnets[0].SubnetId' \
    --filters "Name=availability-zone,Values=${10}" "Name=default-for-az,Values=true")
  SUBNET2B=$(aws ec2 describe-subnets \
    --output text \
    --query 'Subnets[0].SubnetId' \
    --filters "Name=availability-zone,Values=${11}" "Name=default-for-az,Values=true")
  echo "$SUBNET2A"
  echo "$SUBNET2B"

  echo "Creating the AutoScalingGroup Launch Template..."
  aws ec2 create-launch-template \
    --launch-template-name "${12}" \
    --version-description AutoScalingVersion1 \
    --launch-template-data file://config.json \
    --region "${17}"
  echo "Launch Template created..."

  LAUNCHTEMPLATEID=$(aws ec2 describe-launch-templates \
    --launch-template-names "${12}" \
    --query 'LaunchTemplates[0].LaunchTemplateId' \
    --output text)
  echo "$LAUNCHTEMPLATEID"

  echo "Creating the TARGET GROUP and storing the ARN in TARGETARN"
  TARGETARN=$(aws elbv2 create-target-group \
    --name "$8" \
    --protocol HTTP \
    --port 80 \
    --vpc-id "$VPCID" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
  echo "$TARGETARN"

  echo "Creating ELBv2 Elastic Load Balancer..."
  ELBARN=$(aws elbv2 create-load-balancer \
    --name "$9" \
    --subnets "$SUBNET2A" "$SUBNET2B" \
    --security-groups "$4" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)
  echo "$ELBARN"

  aws elbv2 modify-target-group-attributes \
    --target-group-arn "$TARGETARN" \
    --attributes Key=deregistration_delay.timeout_seconds,Value=30

  echo "Waiting for load balancer to be available..."
  aws elbv2 wait load-balancer-available --load-balancer-arns "$ELBARN"
  echo "Load balancer available..."

  aws elbv2 create-listener \
    --load-balancer-arn "$ELBARN" \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn="$TARGETARN"

  echo "Creating Auto Scaling Group..."
  aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name "${13}" \
    --launch-template LaunchTemplateId="$LAUNCHTEMPLATEID" \
    --min-size "${14}" \
    --max-size "${15}" \
    --desired-capacity "${16}" \
    --target-group-arns "$TARGETARN" \
    --vpc-zone-identifier "$SUBNET2A,$SUBNET2B" \
    --health-check-type ELB \
    --health-check-grace-period 300 \
    --tags "Key=module,Value=$7,PropagateAtLaunch=true"

  echo "Waiting for Auto Scaling Group to spin up EC2 instances and attach them to the TargetARN..."
  aws elbv2 wait target-in-service --target-group-arn "$TARGETARN"
  echo "Targets attached to Auto Scaling Group..."

  INSTANCEIDS=$(aws ec2 describe-instances \
    --output text \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --filters "Name=instance-state-name,Values=running,pending" "Name=tag:module,Values=$7")

  if [ "$INSTANCEIDS" != "" ]
  then
    aws ec2 wait instance-running --instance-ids $INSTANCEIDS
    echo "Finished launching instances..."
  else
    echo 'There are no running or pending values in $INSTANCEIDS to wait for...'
  fi

  echo "Creating S3 bucket: ${19}..."
  aws s3api create-bucket \
    --bucket "${19}" \
    --create-bucket-configuration LocationConstraint="${17}"
  echo "Created S3 bucket: ${19}..."

  echo "Creating S3 bucket: ${20}..."
  aws s3api create-bucket \
    --bucket "${20}" \
    --create-bucket-configuration LocationConstraint="${17}"
  echo "Created S3 bucket: ${20}..."

  echo "Uploading image: ./images/illinoistech.png to s3://${19}..."
  aws s3 cp ./images/illinoistech.png "s3://${19}/"
  echo "Uploading image: ./images/rohit.jpg to s3://${19}..."
  aws s3 cp ./images/rohit.jpg "s3://${19}/"
  aws s3 ls "s3://${19}/"

  echo "Uploading image: ./images/elevate.webp to s3://${20}..."
  aws s3 cp ./images/elevate.webp "s3://${20}/"
  echo "Uploading image: ./images/ranking.jpg to s3://${20}..."
  aws s3 cp ./images/ranking.jpg "s3://${20}/"
  aws s3 ls "s3://${20}/"

  URL=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ELBARN" \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

  echo "$URL"
fi