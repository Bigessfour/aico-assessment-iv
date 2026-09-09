# Remote state bonus: S3 bucket + DynamoDB lock table.
# Backend resources themselves are created once by scripts/bootstrap-tf-backend.sh
# (chicken/egg: Terraform cannot store state in a bucket that does not exist yet).
#
# Bucket:  aico-iv-steve-tfstate
# Table:   aico-iv-steve-tflock  (partition key LockID)
#
# No credentials in this file — uses the same AWS profile / env as the CLI.

terraform {
  backend "s3" {
    bucket         = "aico-iv-steve-tfstate"
    key            = "assessment-iv/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aico-iv-steve-tflock"
    encrypt        = true
  }
}
