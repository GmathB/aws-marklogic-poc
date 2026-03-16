
 terraform {
   backend "s3" {
     bucket  = "marklogic-terraform-state-013596899729"
     key     = "marklogic/terraform.tfstate"
     region  = "ap-south-1"
     encrypt = true
     # use_lockfile = true  
     
     # I get an error as `Not a valid S3 backend parameter - use DynamoDB for state locking`
     # But this is not true. dynamodb will be deprecated soon and I wanted to test native locking.
     # Will be investigating this further.
   }
 }
