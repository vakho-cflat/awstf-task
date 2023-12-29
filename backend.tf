terraform {
  backend "s3" {
    bucket         = "devops-tbc-vtabatadze"
    key            = "./terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = ""
  }
}
