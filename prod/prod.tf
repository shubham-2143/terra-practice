module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "michdonaahe"
  acl    = "public-read"
  
  block_public_acls = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = true
  }
}