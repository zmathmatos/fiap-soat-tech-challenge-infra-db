terraform {
  backend "s3" {
    bucket = "fiap-soat-terraform-state-bucket"
    key    = "infra-db/terraform.tfstate"
    region = "us-east-1"
  }
}
