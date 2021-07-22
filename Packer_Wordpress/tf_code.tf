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

#   website {
#   index_document = "index.html"
#   }

#   tags = {
#     "Terraform" : "true"
#   }
# }

# locals {
#   s3_origin_id = "s3origin"
# }

# resource "aws_cloudfront_distribution" "CFDistribution" {
#   origin {
#     domain_name = aws_s3_bucket.s3-bucket.bucket_regional_domain_name
#     origin_id = local.s3_origin_id
#   }

#   enabled = true
#   comment = "TF Cloudfront Distribution"
#   default_root_object = "index.html"

#   default_cache_behavior {
#     allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
#     cached_methods = ["GET", "HEAD"]
#     target_origin_id = local.s3_origin_id

#     forwarded_values {
#       query_string = false

#       cookies {
#         forward = "none"
#       }
#     }
    
#     viewer_protocol_policy = "allow-all"
#     min_ttl = 0
#     default_ttl = 3600
#     max_ttl = 86400
#   }
  
#   restrictions {
#     geo_restriction {
#       restriction_type = "none"
#     }
#   }

#   viewer_certificate {
#     cloudfront_default_certificate = true
#   }
# }

resource "aws_default_vpc" "default" {}

resource "aws_security_group" "SG" {
  name = "SG"
  description = "SG TF"

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

resource "aws_security_group" "DBSG" {
  name = "DBSG"
  description = "DBSG TF"

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [aws_security_group.SG.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
  image_id = "ami-0e7ecbee23c8f8a4b"
  instance_type = "t2.micro"
  key_name = "practical-lab-key-pair"
  security_groups = [aws_security_group.SG.id]

  lifecycle {
    create_before_destroy = true
  }

  user_data = <<-EOF
    #! /bin/bash
    cd /var/www/html/
    sed -i "s/'database_name_here'/'${aws_db_instance.DB.name}'/g" wp-config.php
    sed -i "s/'username_here'/'${aws_db_instance.DB.username}'/g" wp-config.php
    sed -i "s/'password_here'/'${aws_db_instance.DB.password}'/g" wp-config.php
    sed -i "s/'localhost'/'${aws_db_instance.DB.endpoint}'/g" wp-config.php
    echo ${aws_db_instance.DB.endpoint} > test.txt
  EOF
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

  depends_on = [
    aws_db_instance.DB
  ]
}

resource "aws_autoscaling_attachment" "AS_attach" {
  autoscaling_group_name = aws_autoscaling_group.ASG.id
  alb_target_group_arn = aws_lb_target_group.TG.arn
}

resource "aws_autoscaling_policy" "scaleup-cpu-policy" {
  name = "scaleup-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.ASG.name
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = "1"
  cooldown = "120"
  policy_type = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "scaleup-cpu-alarm" {
  alarm_name = "scaleup-cpu-alarm"
  alarm_description = "scaleup-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "1"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
  threshold = "75"
  dimensions = {
  "AutoScalingGroupName" = "aws_autoscaling_group.ASG.name"
  }
  actions_enabled = true
  alarm_actions = [aws_autoscaling_policy.scaleup-cpu-policy.arn]
}

resource "aws_autoscaling_policy" "scaledown-cpu-policy" {
  name = "scaledown-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.ASG.name
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = "-1"
  cooldown = "120"
  policy_type = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "scaledown-cpu-alarm" {
  alarm_name = "scaledown-cpu-alarm"
  alarm_description = "scaledown-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "1"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
  threshold = "20"
  dimensions = {
  "AutoScalingGroupName" = "aws_autoscaling_group.ASG.name"
  }
  actions_enabled = true
  alarm_actions = [aws_autoscaling_policy.scaledown-cpu-policy.arn]
}

# resource "aws_route53_zone" "hostedzone" {
#   name = "hostedzoneexample.zyx"
# }

# resource "aws_route53_record" "arecord" {
#   zone_id = aws_route53_zone.hostedzone.id
#   name = "hostedzoneexample.zyx"
#   type = "A"

#   alias {
#     name = aws_lb.ELB.dns_name
#     zone_id = aws_lb.ELB.zone_id
#       evaluate_target_health = false
#   }
# }

resource "aws_db_instance" "DB" {
  allocated_storage = 5
  engine = "mysql"
  engine_version = "5.7"
  instance_class = "db.t2.micro"
  name = "DBTF"
  identifier = "dbtfid"
  username = "admin"
  password = "PaSSw0rd"
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.DBSG.id]
  backup_retention_period = 1
}

# resource "aws_db_instance" "DBRR" {
#   identifier = "dbrrtfid"
#   replicate_source_db = aws_db_instance.DB.identifier
#   instance_class = "db.t2.micro"
#   apply_immediately = true
#   skip_final_snapshot = true
#   vpc_security_group_ids = [aws_security_group.DBSG.id]
# }

output "rds_endpoint" {
  value = "${aws_db_instance.DB.endpoint}"
}

output "rds_name" {
  value = "${aws_db_instance.DB.name}"
}

output "rds_username" {
  value = "${aws_db_instance.DB.username}"
}

output "rds_password" {
  value = "${aws_db_instance.DB.password}"
  sensitive = true
}