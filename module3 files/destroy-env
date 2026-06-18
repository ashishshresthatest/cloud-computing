#!/bin/bash

echo "Beginning destroy script for module-03 assessment..."

INSTANCEIDS=$(aws ec2 describe-instances \
  --output text \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --filters "Name=instance-state-name,Values=running,pending" "Name=tag:Name,Values=module3-tag")

echo "List of INSTANCEIDS to deregister..."
echo "$INSTANCEIDS"

echo "Finding TARGETARN..."
TARGETARN=$(aws elbv2 describe-target-groups \
  --query 'TargetGroups[*].TargetGroupArn' \
  --output text)

echo "$TARGETARN"

if [ "$INSTANCEIDS" != "" ] && [ "$TARGETARN" != "" ]
then
  INSTANCEIDSARRAY=($INSTANCEIDS)
  for INSTANCEID in ${INSTANCEIDSARRAY[@]};
  do
    echo "Deregistering target $INSTANCEID..."
    aws elbv2 deregister-targets \
      --target-group-arn "$TARGETARN" \
      --targets Id="$INSTANCEID"

    echo "Waiting for target $INSTANCEID to be deregistered..."
    aws elbv2 wait target-deregistered \
      --target-group-arn "$TARGETARN" \
      --targets Id="$INSTANCEID"
  done
else
  echo "There are no running/pending instances or target groups to deregister."
fi

echo "Now terminating the detached INSTANCEIDS..."
if [ "$INSTANCEIDS" != "" ]
then
  aws ec2 terminate-instances --instance-ids $INSTANCEIDS
  echo "Waiting for all instances to report state as TERMINATED..."
  aws ec2 wait instance-terminated --instance-ids $INSTANCEIDS
  echo "Finished destroying instances..."
else
  echo "There are no running instances to terminate."
fi

echo "Looking up ELB ARN..."
ELBARN=$(aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[*].LoadBalancerArn' \
  --output text)

echo "$ELBARN"

if [ "$ELBARN" != "" ]
then
  ELBARNSARRAY=($ELBARN)
  for ELB in ${ELBARNSARRAY[@]};
  do
    echo "Deleting Listener..."
    LISTENERARN=$(aws elbv2 describe-listeners \
      --load-balancer-arn "$ELB" \
      --query 'Listeners[*].ListenerArn' \
      --output text)

    if [ "$LISTENERARN" != "" ]
    then
      aws elbv2 delete-listener --listener-arn "$LISTENERARN"
      echo "Listener deleted..."
    fi

    echo "Deleting Load Balancer..."
    aws elbv2 delete-load-balancer --load-balancer-arn "$ELB"

    echo "Waiting for ELB to be deleted..."
    aws elbv2 wait load-balancers-deleted --load-balancer-arns "$ELB"
  done
else
  echo "No ELBs to delete..."
fi

if [ "$TARGETARN" != "" ]
then
  echo "Deleting target group $TARGETARN..."
  aws elbv2 delete-target-group --target-group-arn "$TARGETARN"
else
  echo "No Target Groups to delete..."
fi

echo "Finished module-03 destroy script."