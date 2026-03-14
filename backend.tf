
 terraform {
   backend "s3" {
     bucket         = "marklogic-terraform-state-013596899729"
     key            = "marklogic/terraform.tfstate"
     region         = "ap-south-1"
     encrypt        = true
     dynamodb_table = "terraform-state-lock"
   }
 }
