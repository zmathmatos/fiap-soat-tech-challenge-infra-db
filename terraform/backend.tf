terraform {
  backend "s3" {
    bucket = "fiap-soat-backend-430891654117"
    key    = "infra-db/terraform.tfstate"
    region = "us-east-1"
  }
}
