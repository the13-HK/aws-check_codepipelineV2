terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "5.32.0"         ## プロバイダーのバージョン
    }
  }
  required_version = "1.7.0"       ## Terraformのバージョン
  
  backend "s3" {
    bucket                  = "tfstate-746235575970"
    key                     = "aws-check_codepipelineV2/terraform.tfstate"
    region                  = "ap-northeast-1"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-northeast-1"
}