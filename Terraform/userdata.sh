#!/bin/bash
yum update -y
yum install -y mc
yum install -y httpd
service httpd start
chkconfig httpd on