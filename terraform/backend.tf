terraform {
  backend "s3" {
    key    = "infra-db/terraform.tfstate"
    region = "us-east-1"
  }
}
