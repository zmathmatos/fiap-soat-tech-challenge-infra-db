terraform {
  backend "s3" {
    key    = "infra/terraform.tfstate"
    region = "us-east-1"
  }
}
