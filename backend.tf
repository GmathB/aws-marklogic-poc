
 terraform {
   backend "s3" {
     bucket         = "marklogic-terraform-state-013596899729"  # Your AWS Account ID
     key            = "marklogic/terraform.tfstate"
     region         = "ap-south-1"
     encrypt        = true
     use_lockfile   = true  # Modern S3-native state locking (replaces deprecated DynamoDB)
   }
 }
