terraform {
  backend "s3" {
    bucket = "fiap-soat-terraform-state-963562973486"
    key    = "infra-db/terraform.tfstate"
    region = "us-east-1"
  }
}
