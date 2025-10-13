provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "tf_state" {
  bucket = "abby-terraform-state-bucket"

  # Optional: keep the bucket safe from deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "terraform-state"
    Environment = "bootstrap"
  }
}

# ✅ New: Separate resource for versioning
resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Optional: Enable server-side encryption for extra security
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_encryption" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
