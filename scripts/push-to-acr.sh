#!/bin/bash

# Script to tag and push all Docker images to Azure Container Registry
# Usage: ./push-to-acr.sh <acr-name>

set -e

if [ -z "$1" ]; then
    echo "Error: ACR name not provided"
    echo "Usage: ./push-to-acr.sh <acr-name>"
    echo "Example: ./push-to-acr.sh myacr123"
    exit 1
fi

ACR_NAME=$1
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

# List of images to push
IMAGES=("identity" "gateway" "frontend" "stakeholders" "tour" "follower-api")

echo "==============================================="
echo "Azure Container Registry Image Push Script"
echo "==============================================="
echo "ACR Name: $ACR_NAME"
echo "ACR Server: $ACR_LOGIN_SERVER"
echo "Images to push: ${IMAGES[@]}"
echo "==============================================="
echo ""

# Login to ACR
echo "🔐 Logging in to Azure Container Registry..."
az acr login --name $ACR_NAME

# Tag and push each image
for IMAGE in "${IMAGES[@]}"; do
    echo ""
    echo "📦 Processing image: $IMAGE"
    echo "   Tagging: $IMAGE:latest -> $ACR_LOGIN_SERVER/$IMAGE:latest"
    docker tag $IMAGE:latest $ACR_LOGIN_SERVER/$IMAGE:latest

    echo "   Pushing to ACR..."
    docker push $ACR_LOGIN_SERVER/$IMAGE:latest

    echo "   ✅ $IMAGE pushed successfully"
done

echo ""
echo "==============================================="
echo "✅ All images pushed successfully!"
echo "==============================================="
echo ""
echo "Next steps:"
echo "1. Deploy to AKS: ./deploy-to-aks.sh $ACR_NAME"
echo "2. Or manually: cd ../k8s/azure && sed 's/{{ACR_NAME}}/$ACR_NAME/g' *.yaml | kubectl apply -f -"
