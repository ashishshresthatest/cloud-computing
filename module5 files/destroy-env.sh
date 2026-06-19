#!/bin/bash

ltconfigfile="./config.json"

echo "Beginning destroy script for module-05 assessment..."

if [ -a "$ltconfigfile" ]
then
  echo "Deleting Launch template configuration file: $ltconfigfile..."
  rm "$ltconfigfile"
else
  echo "Launch template configuration file: $ltconfigfile doesn't exist, moving on..."
fi

echo "Finding Auto Scaling Groups..."
ASGNAMES=$(aws autoscaling describe-auto-scaling-groups \
  --query 'AutoScalingGroups[*].AutoScalingGroupName' \
  --output text)

if [ "$ASGNAMES" != "" ]
then
  for ASGNAME in $ASGNAMES
  do
    echo "Scaling down Auto Scaling Group: $ASGNAME"
    aws autoscaling update-auto-scaling-group \
      --auto-scaling-group-name "$ASGNAME" \
      --min-size 0 \
      --desired-capacity 0

    INSTANCEIDS=$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "$ASGNAME" \
      --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
      --output text)

    if [ "$INSTANCEIDS" != "" ]
    then
      echo "Waiting for ASG instances to terminate: $INSTANCEIDS"
      aws ec2 wait instance-terminated --instance-ids $INSTANCEIDS
    fi

    echo "Deleting Auto Scaling Group: $ASGNAME"
    aws autoscaling delete-auto-scaling-group \
      --auto-scaling-group-name "$ASGNAME" \
      --force-delete
  done
else
  echo "No Auto Scaling Groups found..."
fi

echo "Looking up ELB ARNs..."
ELBARNS=$(aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[*].LoadBalancerArn' \
  --output text)

echo "Looking up Target Group ARNs..."
TARGETARNS=$(aws elbv2 describe-target-groups \
  --query 'TargetGroups[*].TargetGroupArn' \
  --output text)

if [ "$ELBARNS" != "" ]
then
  for ELBARN in $ELBARNS
  do
    echo "Deleting listeners for $ELBARN..."
    LISTENERARNS=$(aws elbv2 describe-listeners \
      --load-balancer-arn "$ELBARN" \
      --query 'Listeners[*].ListenerArn' \
      --output text)

    if [ "$LISTENERARNS" != "" ]
    then
      for LISTENERARN in $LISTENERARNS
      do
        aws elbv2 delete-listener --listener-arn "$LISTENERARN"
      done
    fi

    echo "Deleting Load Balancer: $ELBARN"
    aws elbv2 delete-load-balancer --load-balancer-arn "$ELBARN"
    aws elbv2 wait load-balancers-deleted --load-balancer-arns "$ELBARN"
  done
else
  echo "No ELBs to delete..."
fi

if [ "$TARGETARNS" != "" ]
then
  for TARGETARN in $TARGETARNS
  do
    echo "Deleting target group: $TARGETARN"
    aws elbv2 delete-target-group --target-group-arn "$TARGETARN"
  done
else
  echo "No Target Groups to delete..."
fi

echo "Finding launch templates..."
LAUNCHTEMPLATENAMES=$(aws ec2 describe-launch-templates \
  --query 'LaunchTemplates[*].LaunchTemplateName' \
  --output text)

if [ "$LAUNCHTEMPLATENAMES" != "" ]
then
  for LAUNCHTEMPLATENAME in $LAUNCHTEMPLATENAMES
  do
    echo "Deleting launch template: $LAUNCHTEMPLATENAME"
    aws ec2 delete-launch-template --launch-template-name "$LAUNCHTEMPLATENAME"
  done
else
  echo "No launch templates found..."
fi

echo "Cleaning S3 buckets from arguments.txt if permissions allow..."
if [ -f "$HOME/arguments.txt" ]
then
  set -- $(< "$HOME/arguments.txt")

  for BUCKET in "${19}" "${20}"
  do
    if [ "$BUCKET" != "" ]
    then
      echo "Attempting to empty and delete bucket: $BUCKET"
      aws s3 rm "s3://$BUCKET" --recursive
      aws s3api delete-bucket --bucket "$BUCKET"
      aws s3api wait bucket-not-exists --bucket "$BUCKET"
    fi
  done
else
  echo "No ~/arguments.txt found, skipping named S3 cleanup."
fi

echo "Finished module-05 destroy script."