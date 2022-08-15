#!/bin/bash -xe

exec > >(tee /var/log/cloud-init-output.log | logger -t user-data -s 2>/dev/console) 2>&1

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
mount -t efs -o tls ${EFS_ID}:/ /home/ec2-user/ghost/content

cat << EOF > config.development.json
{
  "url": "http://${LB_DNS_NAME}",
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
        "password": "${DB_PASSWORD}",
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
