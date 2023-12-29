terraform {
  backend "s3" {
    bucket         = "backend-bucket-vt"
    key            = "./terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = ""
   
     config {
      max_lock_duration_seconds = 150
    }
  }
}
