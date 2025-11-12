#!/bin/bash

# ===================================================================
# Build and Push Docker Images to Azure Container Registry
# ===================================================================
# Builds all microservice images and pushes them to ACR
# ===================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
else
    echo -e "${RED}❌ config.env not found!${NC}"
    exit 1
fi

# Navigate to project root (2 levels up from scripts/azure)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Build & Push Docker Images to ACR                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}📋 Configuration:${NC}"
echo -e "   ACR Name:         ${GREEN}$ACR_NAME${NC}"
echo -e "   ACR Server:       ${GREEN}$ACR_NAME.azurecr.io${NC}"
echo -e "   Images to build:  ${GREEN}${#IMAGES[@]} images${NC}"
echo -e "   Project Root:     ${GREEN}$PROJECT_ROOT${NC}"
echo ""

# Check if Docker is running
echo -e "${YELLOW}🐳 Checking if Docker is running...${NC}"
if ! docker info &>/dev/null; then
    echo -e "${RED}❌ Docker is not running!${NC}"
    echo -e "${YELLOW}Please start Docker Desktop and try again.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker is running${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 1: Building Docker Images${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}📦 Building images using docker-compose...${NC}"
docker-compose -f docker-compose.yml build

echo -e "${GREEN}✅ All images built${NC}"
echo ""

# Tag images with docker-compose prefixes to simple names
echo -e "${YELLOW}🏷️  Tagging images...${NC}"
docker tag soa-deployment-identity:latest identity:latest
docker tag soa-deployment-stakeholders:latest stakeholders:latest
docker tag soa-deployment-follower-api:latest follower-api:latest
docker tag soa-deployment-tour:latest tour:latest
docker tag soa-deployment-gateway:latest gateway:latest
docker tag soa-deployment-frontend:latest frontend:latest
echo -e "${GREEN}✅ Images tagged${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 2: Logging into Azure Container Registry${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}🔐 Logging into ACR...${NC}"
az acr login --name "$ACR_NAME"
echo -e "${GREEN}✅ Logged into ACR${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 3: Tagging and Pushing Images to ACR${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

for IMAGE in "${IMAGES[@]}"; do
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📦 Processing: ${GREEN}$IMAGE${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    echo -e "${YELLOW}   🏷️  Tagging: $IMAGE:latest → $ACR_LOGIN_SERVER/$IMAGE:latest${NC}"
    docker tag "$IMAGE:latest" "$ACR_LOGIN_SERVER/$IMAGE:latest"

    echo -e "${YELLOW}   ⬆️  Pushing to ACR...${NC}"
    docker push "$ACR_LOGIN_SERVER/$IMAGE:latest"

    echo -e "${GREEN}   ✅ $IMAGE pushed successfully${NC}"
    echo ""
done

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 4: Verifying Images in ACR${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}🔍 Listing images in ACR...${NC}"
az acr repository list --name "$ACR_NAME" --output table

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ All Images Built and Pushed Successfully!            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}📊 Summary:${NC}"
echo -e "   Registry:  ${GREEN}$ACR_LOGIN_SERVER${NC}"
echo -e "   Images:    ${GREEN}${#IMAGES[@]} images pushed${NC}"
echo ""

echo -e "${YELLOW}📝 Next Steps:${NC}"
echo -e "   Deploy to AKS: ${BLUE}./3-deploy-to-aks.sh${NC}"
echo -e "   OR run full deployment: ${BLUE}./deploy-full-azure.sh${NC}"
echo ""
