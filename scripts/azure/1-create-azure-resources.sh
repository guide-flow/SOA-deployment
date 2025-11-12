#!/bin/bash

# ===================================================================
# Azure Resources Creation Script
# ===================================================================
# Creates Resource Group, Azure Container Registry, and AKS Cluster
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
    echo "Please create config.env in $SCRIPT_DIR"
    exit 1
fi

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Azure Resources Creation Script                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Print configuration
echo -e "${BLUE}📋 Configuration:${NC}"
echo -e "   Resource Group:  ${GREEN}$RESOURCE_GROUP${NC}"
echo -e "   Location:        ${GREEN}$LOCATION${NC}"
echo -e "   ACR Name:        ${GREEN}$ACR_NAME${NC}"
echo -e "   AKS Cluster:     ${GREEN}$AKS_CLUSTER_NAME${NC}"
echo -e "   Node Count:      ${GREEN}$AKS_NODE_COUNT${NC}"
echo -e "   Node VM Size:    ${GREEN}$AKS_NODE_VM_SIZE${NC}"
echo ""

# Check if user is logged in to Azure
echo -e "${YELLOW}🔐 Checking Azure login status...${NC}"
if ! az account show &>/dev/null; then
    echo -e "${RED}❌ Not logged in to Azure!${NC}"
    echo -e "${YELLOW}⚡ Running 'az login'...${NC}"
    az login
else
    echo -e "${GREEN}✅ Already logged in to Azure${NC}"
    ACCOUNT=$(az account show --query name -o tsv)
    echo -e "   Account: ${GREEN}$ACCOUNT${NC}"
fi
echo ""

# Confirm before proceeding
echo -e "${YELLOW}⚠️  This script will create Azure resources that incur costs!${NC}"
echo -e "   Estimated cost: ~\$10-15 for a few days of testing"
echo ""
read -p "Do you want to proceed? (yes/no): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}⏸️  Deployment cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 1: Creating Resource Group${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo -e "${YELLOW}⚡ Resource group '$RESOURCE_GROUP' already exists${NC}"
else
    echo -e "${YELLOW}📦 Creating resource group...${NC}"
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION"
    echo -e "${GREEN}✅ Resource group created${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 2: Registering Azure Providers${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}📝 Registering Microsoft.ContainerRegistry...${NC}"
az provider register --namespace Microsoft.ContainerRegistry
echo -e "${YELLOW}📝 Registering Microsoft.ContainerService...${NC}"
az provider register --namespace Microsoft.ContainerService
echo -e "${GREEN}✅ Providers registered${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 3: Creating Azure Container Registry${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo -e "${YELLOW}⚡ ACR '$ACR_NAME' already exists${NC}"
else
    echo -e "${YELLOW}📦 Creating Azure Container Registry...${NC}"
    az acr create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$ACR_NAME" \
        --sku "$ACR_SKU" \
        --location "$LOCATION"
    echo -e "${GREEN}✅ ACR created${NC}"
fi

echo -e "${YELLOW}🔑 Enabling admin access on ACR...${NC}"
az acr update -n "$ACR_NAME" --admin-enabled true
echo -e "${GREEN}✅ Admin access enabled${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 4: Creating AKS Cluster${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if az aks show --name "$AKS_CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo -e "${YELLOW}⚡ AKS cluster '$AKS_CLUSTER_NAME' already exists${NC}"

    # Check if ACR is attached
    echo -e "${YELLOW}🔗 Verifying ACR attachment...${NC}"
    az aks update \
        --name "$AKS_CLUSTER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --attach-acr "$ACR_NAME"
    echo -e "${GREEN}✅ ACR attachment verified${NC}"
else
    echo -e "${YELLOW}⏳ Creating AKS cluster (this takes 5-10 minutes)...${NC}"
    az aks create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$AKS_CLUSTER_NAME" \
        --node-count "$AKS_NODE_COUNT" \
        --node-vm-size "$AKS_NODE_VM_SIZE" \
        --enable-managed-identity \
        --attach-acr "$ACR_NAME" \
        --generate-ssh-keys \
        --location "$LOCATION"
    echo -e "${GREEN}✅ AKS cluster created${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 5: Configuring kubectl${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}📝 Getting AKS credentials...${NC}"
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing
echo -e "${GREEN}✅ kubectl configured${NC}"

echo ""
echo -e "${YELLOW}🔍 Verifying cluster connection...${NC}"
kubectl get nodes
echo -e "${GREEN}✅ Cluster is accessible${NC}"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Azure Resources Created Successfully!                 ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📊 Resources Created:${NC}"
echo -e "   ✅ Resource Group:     ${GREEN}$RESOURCE_GROUP${NC}"
echo -e "   ✅ Container Registry: ${GREEN}$ACR_NAME.azurecr.io${NC}"
echo -e "   ✅ AKS Cluster:        ${GREEN}$AKS_CLUSTER_NAME${NC}"
echo -e "   ✅ Nodes:              ${GREEN}$AKS_NODE_COUNT x $AKS_NODE_VM_SIZE${NC}"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo -e "   1️⃣  Build and push Docker images: ${BLUE}./2-build-and-push-images.sh${NC}"
echo -e "   2️⃣  Deploy to AKS: ${BLUE}./3-deploy-to-aks.sh${NC}"
echo -e "   OR run full deployment: ${BLUE}./deploy-full-azure.sh${NC}"
echo ""

if [[ "$COST_REMINDER" == "true" ]]; then
    echo -e "${YELLOW}💰 Cost Reminder:${NC}"
    echo -e "   Your cluster is now running and incurring costs (~\$0.10/hour)"
    echo -e "   To stop the cluster: ${BLUE}az aks stop --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP${NC}"
    echo -e "   To delete everything: ${BLUE}./cleanup-azure.sh${NC}"
    echo ""
fi
