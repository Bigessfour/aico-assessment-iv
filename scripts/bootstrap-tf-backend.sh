#!/usr/bin/env bash
# =============================================================================
# bootstrap-tf-backend.sh
#
# Creates (idempotently) the S3 bucket + DynamoDB table used by terraform/backend.tf.
# Why a script? Terraform cannot initialize an S3 backend before the bucket exists.
#
# Safe for the class account: unique names under aico-iv-steve-*.
# Does NOT touch the EKS cluster.
# =============================================================================
set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-codeplatoon}"
AWS_REGION="${AWS_REGION:-us-east-1}"
BUCKET="${TF_STATE_BUCKET:-aico-iv-steve-tfstate}"
TABLE="${TF_LOCK_TABLE:-aico-iv-steve-tflock}"

export AWS_PROFILE AWS_REGION

echo "Profile=$AWS_PROFILE Region=$AWS_REGION"
echo "Bucket=$BUCKET Table=$TABLE"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "S3 bucket already exists"
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION"
  echo "Created S3 bucket $BUCKET"
fi

aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

if aws dynamodb describe-table --table-name "$TABLE" >/dev/null 2>&1; then
  echo "DynamoDB lock table already exists"
else
  aws dynamodb create-table \
    --table-name "$TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST >/dev/null
  aws dynamodb wait table-exists --table-name "$TABLE"
  echo "Created DynamoDB table $TABLE"
fi

echo "Backend ready. Next: cd terraform && terraform init"
