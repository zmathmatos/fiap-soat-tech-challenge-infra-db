terraform {
  backend "s3" {
    bucket = "fiap-soat-backend-bucket"
    key    = "infra-db/terraform.tfstate"
    region = "us-east-1"
  }
}
