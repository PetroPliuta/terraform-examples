#!/bin/bash -xe

exec > >(tee /var/log/cloud-init-output.log | logger -t user-data -s 2>/dev/console) 2>&1

REGION=$(/usr/bin/curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')
EFS_ID=$(aws efs describe-file-systems --query 'FileSystems[?Name==`ghost_content`].FileSystemId' --region $REGION --output text)

SSM_DB_PASSWORD="/ghost/dbpassw"
DB_PASSWORD=$(aws ssm get-parameter --name $SSM_DB_PASSWORD --query Parameter.Value --with-decryption --region $REGION --output text)
DB_NAME="ghost"
DB_URL=$(aws rds describe-db-instances --region us-east-1 --query 'DBInstances[?DBInstanceIdentifier==`ghost`].Endpoint.Address' --output text)
DB_USER="awsuser"

LB_DNS_NAME=$(aws elbv2 describe-load-balancers --region us-east-1 --query 'LoadBalancers[?LoadBalancerName==`ghost-app`]'.DNSName --output text)

### Install pre-reqs
curl -sL https://rpm.nodesource.com/setup_16.x | sudo bash -
sudo yum install -y nodejs amazon-efs-utils
sudo npm install ghost-cli@latest -g

# sudo adduser ghost_user
# sudo usermod -aG wheel ghost_user
cd /home/ec2-user/

sudo -u ec2-user ghost install local

### EFS mount
mkdir -p /home/ec2-user/ghost/content
sudo pip3 install botocore
mount -t efs -o tls $EFS_ID:/ /home/ec2-user/ghost/content

cat << EOF > config.development.json
{
  "url": "http://$LB_DNS_NAME",
  "server": {
    "port": 2368,
    "host": "0.0.0.0"
  },
  "database": {
    "client": "mysql",
    "connection": {
        "host": "${DB_URL}",
        "port": 3306,
        "user": "${DB_USER}",
        "password": "$DB_PASSWORD",
        "database": "${DB_NAME}"
    }
  },
  "mail": {
    "transport": "Direct"
  },
  "logging": {
    "transports": [
      "file",
      "stdout"
    ]
  },
  "process": "local",
  "paths": {
    "contentPath": "/home/ec2-user/ghost/content/ec2"
  }
}
EOF

sudo -u ec2-user ghost stop
mkdir -p /home/ec2-user/ghost/content/ec2
if [ "$(ls -A /home/ec2-user/ghost/content/ec2)" ]; then
    rm -rf /home/ec2-user/content/*
else
    mv /home/ec2-user/content/* /home/ec2-user/ghost/content/ec2
    chown -vR ec2-user:ec2-user /home/ec2-user/ghost/content/ec2
fi 
sudo -u ec2-user ghost start
