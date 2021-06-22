terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.45.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region = "us-east-1"
}


data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

# resource "aws_s3_bucket" "s3-bucket" {
#   bucket = "practical-lab-s3-bucket-656233"
#   acl = "public-read"
# }

resource "aws_default_vpc" "default" {}

resource "aws_security_group" "SG" {
  name = "SG"
  description = "Description"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Terraform" : "true"
  }
}

resource "aws_default_subnet" "az1" {
  availability_zone = "us-east-1a"
  tags = {
    "Terraform" : "true"
  }
}

resource "aws_default_subnet" "az2" {
  availability_zone = "us-east-1b"
  tags = {
    "Terraform" : "true"
  }
}

resource "aws_lb" "ELB" {
  name = "ELB"
  load_balancer_type = "application"
  subnets = [aws_default_subnet.az1.id, aws_default_subnet.az2.id]
  security_groups = [aws_security_group.SG.id]

  tags = {
    "Terraform" : "true"
  }
}

resource "aws_lb_listener" "lblistener" {
  load_balancer_arn = aws_lb.ELB.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.TG.arn
  }
}

resource "aws_lb_target_group" "TG" {
  name = "TFTG"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_default_vpc.default.id

  stickiness {
    enabled = true
    type    = "lb_cookie"
  }

  health_check {
    healthy_threshold   = 2
    interval            = 30
    protocol            = "HTTP"
    unhealthy_threshold = 2
  }

  depends_on = [
    aws_lb.ELB
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "LC" {
  name_prefix = "launch_configuration"
  image_id = "ami-0d5eff06f840b45e9"
  instance_type = "t2.micro"
  key_name = "practical-lab-key-pair"
  security_groups = [aws_security_group.SG.id]

  lifecycle {
    create_before_destroy = true
  }

  user_data = file("userdata.sh")
}

resource "aws_autoscaling_group" "ASG" {
  name = "ASG"
  launch_configuration = aws_launch_configuration.LC.name
  availability_zones = ["us-east-1a","us-east-1b"]
  desired_capacity = 1
  max_size = 3
  min_size = 1

  lifecycle {
    create_before_destroy = true
  }
  
  tag {
    key = "Terraform"
    value = "true"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_attachment" "AS_attach" {
  autoscaling_group_name = aws_autoscaling_group.ASG.id
  alb_target_group_arn = aws_lb_target_group.TG.arn
}