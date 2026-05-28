output "public_ip" {
  value = aws_instance.dev.public_ip
}
output "private_ip" {
  value = aws_instance.dev.private_ip
}
output "bucketname" {
  value = aws_s3_bucket.name.id
}