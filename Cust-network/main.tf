resource "aws_instance" "dev" {
    subnet_id = aws_subnet.sub-1.id
  ami = var.ami_id
  instance_type = var.type
  vpc_security_group_ids = [aws_security_group.SG.id]
  tags = {
    Name = "dev"
  }
}
resource "aws_instance" "test" {
    subnet_id = aws_subnet.sub-2.id
  ami = var.ami_id
  instance_type = var.type
  tags = {
    Name = "test"
  }
}

resource "aws_vpc" "vpc" {
    region = var.region
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "VPC1"
      }
}

resource "aws_subnet" "sub-1" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "subnet-1"
  }
}

resource "aws_subnet" "sub-2" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "subnet-2"
  }
}

resource "aws_internet_gateway" "name" {
    vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "IG"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "Public_route"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "Private_route"
  }
}

resource "aws_route_table_association" "pub" {
  subnet_id = aws_subnet.sub-1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pvt" {
  subnet_id = aws_subnet.sub-2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_eip" "name" {
  domain = "vpc"
  tags = {
    Name = "my_eip"
  }
}

resource "aws_nat_gateway" "name" {
  allocation_id = aws_eip.name.id
  subnet_id = aws_subnet.sub-1.id
}

resource "aws_route" "nat-rt" {
  nat_gateway_id = aws_nat_gateway.name.id
  destination_cidr_block = "0.0.0.0/0"
  route_table_id = aws_route_table.private.id
}

resource "aws_route" "ig-rt" {
  gateway_id = aws_internet_gateway.name.id
  route_table_id = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_security_group" "SG" {
  description = "Allow SSH access"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG"
  }
}
resource "aws_db_subnet_group" "name" {
  subnet_ids = [aws_subnet.sub-2.id, aws_subnet.sub-1.id]
  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_db_instance" "dtbs" {
     region = "us-east-1"
     availability_zone = "us-east-1b"
     db_subnet_group_name = aws_db_subnet_group.name.id
    engine = "mysql"
    engine_version = "8.4.8"
  allocated_storage = 10
  instance_class = "db.t4g.micro"
  #manage_master_user_password = false
  identifier = "database-1"
  username = "admin"
  password = "admin1234"
  #maintenance_window = "sun:04:00-sun:05:00"
  apply_immediately = true
  backup_window = "01:00-02:00"
  publicly_accessible = false
  backup_retention_period = "7"
  deletion_protection = false
  skip_final_snapshot = true
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn
}

resource "aws_iam_role" "rds_monitoring" {
  name = "rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "read_replica" {
  identifier            = "read-replica-db"
  replicate_source_db   = aws_db_instance.dtbs.arn

  instance_class        = "db.t4g.micro"
  publicly_accessible   = false

  db_subnet_group_name  = aws_db_subnet_group.name.id
  vpc_security_group_ids = [aws_security_group.SG.id]

  apply_immediately = true

  tags = {
    Name = "read-replica-db"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_lambda_function" "name" {
  function_name = "new_function"
  handler = "app.lambda_handler"
  filename = "app.zip"
  runtime = "python3.12"
  role = aws_iam_role.lambda_role.arn
   source_code_hash = filebase64sha256("app.zip")
}

resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name                = "lambda-every-5-min"
  description         = "Trigger Lambda every 5 minutes"
  schedule_expression = "rate(2 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.lambda_schedule.name
  target_id = "lambda-target"
  arn       = aws_lambda_function.name.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.name.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn
}


resource "aws_s3_bucket" "name" {
  bucket = var.bucket
}

