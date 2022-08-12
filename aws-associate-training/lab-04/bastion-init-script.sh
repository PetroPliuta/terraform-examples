#!/usr/bin/env bash

yum install -y docker
docker pull ghost:4.12
docker tag ghost:4.12 ${DOCKER_IMAGE}
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${REGISTRY_ID}.dkr.ecr.${REGION}.amazonaws.com    
docker push ${DOCKER_IMAGE}
