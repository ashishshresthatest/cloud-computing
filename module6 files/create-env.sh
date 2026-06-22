#!/bin/bash

if [ $# -ne 22 ]
then
  echo "You don't have enough variables in your arguments.txt, perhaps you forgot to run: bash ./create-env.sh \$(< ~/arguments.txt)"
  exit 1
fi

SECRET_ID=$(aws secretsmanager list-secrets \
  --filters Key=name,Values="${21}" \
  --query 'SecretList[0].ARN' \
  --output text)

if [ "$SECRET_ID" = "None" ] || [ "$SECRET_ID" = "" ]
then
  echo "You haven't created the secret named ${21}."
  echo "Run: bash ./create-secrets.sh \$(< ~/arguments.txt)"
  exit 1
fi

USERVALUE=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ID" \
  --query 'SecretString' \
  --output text | jq -r '.user')

PASSVALUE=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ID" \
  --query 'SecretString' \
  --output text | jq -r '.pass')

echo "******************************************************************************"
echo "Creating RDS instance ${22}..."
echo "******************************************************************************"
aws rds create-db-instance \
  --db-instance-identifier "${22}" \
  --db-instance-class db.t3.micro \
  --engine mariadb \
  --master-username "$USERVALUE" \
  --master-user-password "$PASSVALUE" \
  --allocated-storage 20 \
  --db-name employee_database \
  --publicly-accessible \
  --tags "Key=assessment,Value=${7}"

echo "******************************************************************************"
echo "Waiting for RDS instance ${22} to be created..."
echo "This might take around 5-15 minutes..."
echo "******************************************************************************"
aws rds wait db-instance-available --db-instance-identifier "${22}"

echo "******************************************************************************"
echo "Creating RDS read-replica instance ${22}-read-replica..."
echo "******************************************************************************"
aws rds create-db-instance-read-replica \
  --db-instance-identifier "${22}-read-replica" \
  --source-db-instance-identifier "${22}" \
  --publicly-accessible \
  --tags "Key=assessment,Value=${7}"

echo "******************************************************************************"
echo "Waiting for RDS read-replica instance to be created..."
echo "This might take another 5-15 minutes..."
echo "******************************************************************************"
aws rds wait db-instance-available --db-instance-identifier "${22}-read-replica"

echo "******************************************************************************"
echo "Retrieving the RDS Endpoint Address and printing to the screen..."
RDS_Address=$(aws rds describe-db-instances \
  --db-instance-identifier "${22}" \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)
echo "$RDS_Address"

echo "Retrieving the RDS Read Replica Endpoint Address and printing to the screen..."
RDS_RR_Address=$(aws rds describe-db-instances \
  --db-instance-identifier "${22}-read-replica" \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)
echo "$RDS_RR_Address"