**Create**

Key pair:\
`aws ec2 create-key-pair --key-name cli_ec2_key --query 'KeyMaterial' --output text > cli_ec2_key.pem`

Security group and rules:\
`aws ec2 create-security-group --group-name cli_sg --description "cli_sg"`\
`aws ec2 authorize-security-group-ingress --group-name cli_sg --protocol tcp --port 80 --cidr 0.0.0.0/0`\
`aws ec2 authorize-security-group-ingress --group-name cli_sg --protocol tcp --port 22 --cidr 0.0.0.0/0`\
`aws ec2 authorize-security-group-ingress --group-name cli_sg --protocol tcp --port 443 --cidr 0.0.0.0/0`

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

S3 bucket:\
`aws s3 mb s3://practical-lab-cli-bucket`

Coppy content to S3:\
`aws s3 cp C:\Users\G1lev14\Desktop\test\dist s3://practical-lab-cli-bucket/ --recursive --acl public-read`

S3 static website hosting:\
`aws s3 website s3://practical-lab-cli-bucket/ --index-document index.html`

CloudFront:\
`aws cloudfront create-distribution --origin-domain-name practical-lab-cli-bucket.s3-website-us-east-1.amazonaws.com`

RDS:\
`aws rds create-db-instance --db-instance-identifier cli-rds-mysql --db-instance-class db.t2.micro --engine mysql --availability-zone us-east-1a --master-username admin --master-user-password Password --allocated-storage 10`

Read replica:\
`aws rds create-db-instance-read-replica --db-instance-identifier cli-rds-mysql-rr --source-db-instance-identifier cli-rds-mysql`

**Destroy**

Autoscaling group:\
`aws autoscaling delete-auto-scaling-group --auto-scaling-group-name cli_asg --force-delete`

Launch configuration:\
`aws autoscaling delete-launch-configuration --launch-configuration-name cli_lc`

Load balancer:\
`aws elbv2 delete-load-balancer --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:617155810538:loadbalancer/app/cli-lb/42bb62f238ed3127`

Target group:\
`aws elbv2 delete-target-group --target-group-arn arn:aws:elasticloadbalancing:us-east-1:617155810538:targetgroup/cli-tg/f7ad8f8a1dfeee92`

🔥CloudFront (used jq):\
`aws cloudfront get-distribution-config --id EKIAYSEMO17FH | jq '. | .ETag'` - ETag is requiered for further actions\
`aws cloudfront get-distribution-config --id EKIAYSEMO17FH | jq '. | .DistributionConfig' > distconfig`\
in 'distconfig' file state `"Enabled": true` should be changed to `"Enabled": false`\
`aws cloudfront update-distribution --id EKIAYSEMO17FH --if-match E17S3MLB0OW5JW --distribution-config file://distconfig`\
`aws cloudfront get-distribution-config --id EKIAYSEMO17FH | jq '. | .ETag'` - should be executed 2nd time cuz after distribution update ETag has been changed\
`aws cloudfront delete-distribution --id EKIAYSEMO17FH --if-match EUSGNMUABF7TO`

S3 content removal:\
`aws s3 rm s3://practical-lab-cli-bucket --recursive`

Bucket removal:\
`aws s3api delete-bucket --bucket practical-lab-cli-bucket --region us-east-1`

RDS read replica:\
`aws rds delete-db-instance --db-instance-identifier cli-rds-mysql-rr --skip-final-snapshot`

RDS db:\
`aws rds delete-db-instance --db-instance-identifier cli-rds-mysql --skip-final-snapshot`
