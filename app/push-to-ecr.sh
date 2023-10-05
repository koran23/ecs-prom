#!/bin/bash

REPOSITORY_NAME="your-repo-name"
IMAGE_TAG="your-image-tag"
AWS_REGION="your-region" 
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Authenticate Docker to the ECR registry
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build the Docker image
docker build -t $REPOSITORY_NAME .

# Tag the Docker image
docker tag $REPOSITORY_NAME:latest $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME:$IMAGE_TAG

# Push the Docker image to ECR
docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME:$IMAGE_TAG

echo "Image pushed to ECR: $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME:$IMAGE_TAG"
