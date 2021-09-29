terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_security_group" "PublicEC2SG" {
  tags = {
    Name = "PublicEc2SG"
  }
  ingress {
    description = "allow TLS inbound traffic"
    from_port   = 443
    to_port     = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow regular http inbound traffic"
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow ssh from my network"
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amiid" {
  most_recent = true
  owners = ["self"]

  filter {
    name   = "name"
    values = ["packer*"]
  }

  filter {
    name = "tag:Name"
    values = ["Packer"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "test" {
  ami = "${data.aws_ami.amiid.id}"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.PublicEC2SG.id]
  tags = {
    Name = "TestInstance"
  }
  key_name = "practical-lab-key-pair"
  user_data = <<-EOF
    #! /bin/bash
    cd /var/www/html/
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    cp wp-cli.phar /usr/bin/wp
    mv wp-cli.phar /usr/local/bin/wp
    dig +short myip.opendns.com @resolver1.opendns.com > ip.txt
    echo --------------------------123123---------------------------
    cat ip.txt
    wget https://raw.githubusercontent.com/fongakahate/ui_config/main/env.sh
    chmod +x env.sh
    ./env.sh
    source ~/.bash_profile
    echo $ec2ip
    echo --------------------------123123---------------------------
  EOF
}

output "instance_ip_addr" {
  value = aws_instance.test.private_ip
}
