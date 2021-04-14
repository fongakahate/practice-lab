**Create**

Key pair:\
`aws ec2 create-key-pair --key-name cli_ec2_key --query 'KeyMaterial' --output text > cli_ec2_key.pem`

Security group and rules:\
`aws ec2 create-security-group --group-name cli_sg --description "cli_sg"`\
`aws ec2 authorize-security-group-ingress --group-name cli_sg --protocol tcp --port 80 --cidr 0.0.0.0/0`\
`aws ec2 authorize-security-group-ingress --group-name cli_sg --protocol tcp --port 22 --cidr 0.0.0.0/0`\
`aws ec2 authorize-security-group-ingress --group-name cli_sg --protocol tcp --port 443 --cidr 0.0.0.0/0`\

Launch configuration:\
`aws autoscaling create-launch-configuration --launch-configuration-name cli_lc --key-name cli_ec2_key --security-groups sg-06f821da55b669771 --image-id ami-0533f2ba8a1995cf9 --instance-type t2.micro`

Load balancer:\
`aws elbv2 create-load-balancer --name cli-lb --subnets subnet-bc4827e3 subnet-d8e881f9 --security-groups sg-06f821da55b669771`

Target group:\
`aws elbv2 create-target-group --name cli-tg --protocol HTTP --port 80 --vpc-id vpc-7810af05`

Adding instances to the target group:\
`aws elbv2 register-targets --target-group-arn targetgroup-arn --targets Id=i-0abcdef1234567890 Id=i-1234567890abcdef0`

Listener for the load balancer:\
`aws elbv2 create-listener --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:617155810538:loadbalancer/app/cli-lb/42bb62f238ed3127 --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:us-east-1:617155810538:targetgroup/cli-tg/f7ad8f8a1dfeee92`

Autoscaling group:\
`aws autoscaling create-auto-scaling-group --auto-scaling-group-name cli_asg --launch-configuration-name cli_lc --availability-zones us-east-1a --min-size 1 --max-size 3 --desired-capacity 2 --target-group-arns arn:aws:elasticloadbalancing:us-east-1:617155810538:targetgroup/cli-tg/f7ad8f8a1dfeee92`

Scaling policy:\
`aws autoscaling put-scaling-policy --policy-name cpu75-scaling-policy-cli --auto-scaling-group-name cli_asg --policy-type TargetTrackingScaling --target-tracking-configuration file://scaling_policy.json`

**Destroy**

Autoscaling group:\
`aws autoscaling delete-auto-scaling-group --auto-scaling-group-name cli_asg --force-delete`

Launch configuration:\
`aws autoscaling delete-launch-configuration --launch-configuration-name cli_lc`

Load balancer:\
`aws elbv2 delete-load-balancer --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:617155810538:loadbalancer/app/cli-lb/42bb62f238ed3127`

Target group:\
`aws elbv2 delete-target-group --target-group-arn arn:aws:elasticloadbalancing:us-east-1:617155810538:targetgroup/cli-tg/f7ad8f8a1dfeee92`
