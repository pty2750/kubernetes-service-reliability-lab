terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "telemetry" {
  bucket_prefix = "reliability-lab-"
}

resource "aws_s3_bucket_public_access_block" "telemetry" {
  bucket = aws_s3_bucket.telemetry.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "telemetry" {
  bucket = aws_s3_bucket.telemetry.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "telemetry" {
  bucket = aws_s3_bucket.telemetry.id

  rule {
    id     = "expire-lab-telemetry"
    status = "Enabled"

    filter {
      prefix = "telemetry/"
    }

    expiration {
      days = 30
    }
  }
}

output "telemetry_bucket_name" {
  value = aws_s3_bucket.telemetry.id
}