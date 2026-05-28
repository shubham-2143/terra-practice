terraform {
  backend "s3" {
    bucket = "shubhamsontakke0062"
    key = "terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
  }
}