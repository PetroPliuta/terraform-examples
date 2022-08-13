#!/usr/bin/env bash

yum install -y docker
systemctl start docker
docker pull ghost:latest
docker tag ghost:latest ${DOCKER_IMAGE}
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${REGISTRY_ID}.dkr.ecr.${REGION}.amazonaws.com    
docker push ${DOCKER_IMAGE}
