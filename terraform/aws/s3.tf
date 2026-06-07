# Sigilos website bucket
resource "aws_s3_bucket" "sigilos_site" {
  bucket = "sigilos.st"
}

resource "aws_s3_bucket_public_access_block" "sigilos_site" {
  bucket = aws_s3_bucket.sigilos_site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Homelab backups bucket
resource "aws_s3_bucket" "homelab_backups" {
  bucket = "sigilos-homelab-backups"
}

resource "aws_s3_bucket_public_access_block" "homelab_backups" {
  bucket = aws_s3_bucket.homelab_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
