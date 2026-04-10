terraform {
  backend "s3" {
    bucket = "fiap-soat-terraform-state-283756756385"
    key    = "infra-db/terraform.tfstate"
    region = "us-east-1"
  }
}
