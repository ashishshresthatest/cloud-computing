#!/bin/bash
##############################################################################
# Module-03
# This assignment requires you to launch 3 EC2 instances from the commandline,
# register them with a target-group, and then attach them to an ELB
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
##############################################################################

if [ $# -ne 11 ]
then
  echo 'You do not have enough variable in your arugments.txt, perhaps you forgot to run: bash ./create-env.sh $(< ~/arguments.txt)'
  exit 1
else
echo "Finding and storing default VPCID value..."
# https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ec2/describe-vpcs.html
VPCID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[*].VpcId" --output=text)
echo $VPCID

echo "Finding and storing the subnet IDs for defined in arguments.txt Availability Zone 1 and 2..."
SUBNET2A=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${10}")
SUBNET2B=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${11}")
echo $SUBNET2A
echo $SUBNET2B

echo 'Creating the TARGET GROUP and storing the ARN in $TARGETARN...'
# https://awscli.amazonaws.com/v2/documentation/api/2.0.34/reference/elbv2/create-target-group.html
TARGETARN=$(aws elbv2 create-target-group \
  --name "$8" \
  --protocol HTTP \
  --port 80 \
  --vpc-id "$VPCID" \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "Creating ELBv2 Elastic Load Balancer..."
#https://awscli.amazonaws.com/v2/documentation/api/2.0.34/reference/elbv2/create-load-balancer.html
ELBARN=$(aws elbv2 create-load-balancer \
  --name "$9" \
  --subnets "$SUBNET2A" "$SUBNET2B" \
  --security-groups "$4" \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)
echo $ELBARN

# AWS elbv2 wait for load-balancer available
# https://awscli.amazonaws.com/v2/documentation/api/latest/reference/elbv2/wait/load-balancer-available.html
echo "Waiting for load balancer to be available..."
aws elbv2 wait load-balancer-available --load-balancer-arns "$ELBARN"
echo "Load balancer available..."
# create AWS elbv2 listener for HTTP on port 80
#https://awscli.amazonaws.com/v2/documentation/api/latest/reference/elbv2/create-listener.html
aws elbv2 create-listener \
  --load-balancer-arn "$ELBARN" \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn="$TARGETARN" 

echo "Beginning to create and launch instances..."
# https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ec2/run-instances.html
aws ec2 run-instances \
  --image-id "$1" \
  --instance-type "$2" \
  --key-name "$3" \
  --security-group-ids "$4" \
  --count "$5" \
  --user-data file://"$6" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$7}]" 

# Collect Instance IDs
# https://stackoverflow.com/questions/31744316/aws-cli-filter-or-logic
INSTANCEIDS=$(aws ec2 describe-instances --output=text --query 'Reservations[*].Instances[*].InstanceId' --filter "Name=instance-state-name,Values=running,pending" "Name=tag:Name,Values=$7")

#https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ec2/wait/instance-running.html
echo "Waiting until instances are in the RUNNING state..."
echo $INSTANCEIDS

if [ "$INSTANCEIDS" != "" ]
  then
    aws ec2 wait instance-running --instance-ids $INSTANCEIDS
    echo "Waiting for Instances to be in the RUNNING state..."
    echo "$INSTANCEIDS to be registered with the target group..."
    # https://awscli.amazonaws.com/v2/documentation/api/2.0.34/reference/elbv2/register-targets.html
    # Assignes the value of $EC2IDS and places each element (seperated by a space) into an array element
    INSTANCEIDSARRAY=($INSTANCEIDS)
    for INSTANCEID in ${INSTANCEIDSARRAY[@]};
      do
      aws elbv2 register-targets \
        --target-group-arn "$TARGETARN" \
        --targets Id="$INSTANCEID" 
      done
  else
    echo "There are no running or pending instances in $INSTANCEIDS to wait for..."
fi 

# Retreive ELBv2 URL via aws elbv2 describe-load-balancers --query and print it to the screen
#https://awscli.amazonaws.com/v2/documentation/api/latest/reference/elbv2/describe-load-balancers.html
URL=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ELBARN" \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo $URL

# end of outer fi - based on arguments.txt content
fi