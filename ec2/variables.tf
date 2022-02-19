variable instance-type {
  type        = string
  default     = "t2.micro"
  description = "EC2 Instance type"
}
variable instances-count{
    type = number
    default = 2
    description = "Count of ec2 instances"
}
variable subnets {
    type = list
    description = "subnets"
}
variable ec2-sg {
  type        = string
  description = "Security group for EC2 instances"
}

variable user-data {
    type = string
    default = <<EOF
#!/bin/bash
sudo apt update
sudo apt -y install nginx
sudo systemctl enable --now nginx

INSTANCE_ID=$(curl 169.254.169.254/latest/meta-data/instance-id)
echo "Instance ID: $INSTANCE_ID" >>/var/www/html/index.nginx-debian.html

#PHP
sudo apt -y install php-fpm

cat <<END >/etc/nginx/sites-enabled/default
server {
    listen 80 default_server;
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # pass PHP scripts to FastCGI server
    #
    location ~ \.php$ {
           include snippets/fastcgi-php.conf;
           fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
}
END

sudo systemctl restart nginx
cat <<END >/var/www/html/info.php
<?php phpinfo();
?>
END
EOF
    description = "bootstrap script"
}