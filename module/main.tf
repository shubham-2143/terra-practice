resource "aws_instance" "name" {
  instance_type = var.type
  ami = var.ami
}
resource "aws_s3_bucket" "name" {
  bucket = var.bkt
}
resource "aws_s3_bucket_versioning" "name" {
  bucket = aws_s3_bucket.name.id

  versioning_configuration {
    status = "Disabled"
  }
}

