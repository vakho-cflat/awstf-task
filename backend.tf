terraform {
  backend "s3" {
    bucket         = "backend-bucket-vt"
    key            = "./terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = ""
    # would use dynamodb on production
  }
}
