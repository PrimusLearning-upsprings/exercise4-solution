terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.42.0"
    }
  }
}

provider "aws" {
  # Configuration options
}

resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = var.vpc_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "igw"
  }
}

resource "aws_route_table" "pub-rt" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "pub-rt"
  }
}

resource "aws_route_table" "priv-rt" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.my_nat1.id
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.my_nat2.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_nat_gateway.my_nat1.id
  }

   route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_nat_gateway.my_nat2.id
  }

  tags = {
    Name = "priv-rt"
  }
}

resource "aws_security_group" "sec-tf" {
  vpc_id      = aws_vpc.my-vpc.id
  description = "allows web traffic"
  name        = "sec-tf"
  tags = {
    Name = "sec-tf"
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks  = ["0.0.0.0/0"]

  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks  = ["0.0.0.0/0"]

  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "pub-subnet-1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_prefix[0].cidr_block
  availability_zone = "us-east-1a"

  tags = {
    Name =  var.subnet_prefix[0].name
  }
}

resource "aws_subnet" "pub-subnet-2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_prefix[1].cidr_block
  availability_zone = "us-east-1b"

  tags = {
    Name = var.subnet_prefix[1].name
  }
}

resource "aws_subnet" "priv-subnet-1" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = var.subnet_prefix[2].cidr_block
  availability_zone = "us-east-1b"

  tags = {
    Name =  var.subnet_prefix[2].name
  }
}

resource "aws_subnet" "priv-subnet-2" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = var.subnet_prefix[3].cidr_block
  availability_zone = "us-east-1b"

  tags = {
    Name =  var.subnet_prefix[3].name
  }
}


resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.pub-subnet-1.id
  route_table_id = aws_route_table.pub-rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.pub-subnet-2.id
  route_table_id = aws_route_table.pub-rt.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.priv-subnet-2.id
  route_table_id = aws_route_table.pub-rt.id
}

resource "aws_route_table_association" "d" {
  subnet_id      = aws_subnet.priv-subnet-2.id
  route_table_id = aws_route_table.pub-rt.id
}

resource "aws_eip" "my_eip1" {
  domain = vpc
  tags = {
    Name = my_eip1
  }
}

resource "aws_eip" "my_eip2" {
  domain = vpc
  tags = {
    Name = my_eip2
  }
}

resource "aws_nat_gateway" "my_nat1" {
  allocation_id = aws_eip.my_eip1.id
  subnet_id     = aws_subnet.pub-subnet-1.id

  tags = {
    Name = "my_nat1"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "my_nat2" {
  allocation_id = aws_eip.my_eip2.id
  subnet_id     = aws_subnet.pub-subnet-2.id

  tags = {
    Name = "my_nat2"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_lb" "my_lb" {
  name               = "my_lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sec-tf.id]
  subnets            = [aws_subnet.priv_subnet-1.id, aws_subnet.priv_subnet-2.id]

#   enable_deletion_protection = true

#   access_logs {
#     bucket  = aws_s3_bucket.lb_logs.id
#     prefix  = "test-lb"
#     enabled = true
#   }

#   tags = {
#     Environment = "production"
#   }
}

resource "aws_lb_target_group" "my-tg" {
  name     = "my-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my-vpc.id
  target_type = "instance"
}

resource "aws_launch_template" "webservers" {
  name_prefix   = "webserver"
  image_id      = "ami-080e1f13689e07408"
  instance_type = "t3.micro"
}

resource "aws_autoscaling_group" "my-asg" {
  availability_zones = ["us-east-1a", "us-east-1b"]
  desired_capacity   = 2
  max_size           = 5
  min_size           = 2

  launch_template {
    id      = aws_launch_template.webserver.id
    version = "$Latest"
  }
}

resource "aws_lb_listener" "my-listener" {
  load_balancer_arn = aws_lb.my_lb.arn
  port              = "80"
  protocol          = "HTTP"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my-tg.arn
  }
}