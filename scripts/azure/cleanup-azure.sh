#!/bin/bash

# ===================================================================
# Azure Resources Cleanup Script
# ===================================================================
# Deletes all Azure resources to avoid incurring costs
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

echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║        Azure Resources Cleanup Script                    ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}⚠️  WARNING: This will DELETE all Azure resources!${NC}"
echo ""
echo -e "${BLUE}Resources to be deleted:${NC}"
echo -e "   🗑️  AKS Cluster:        ${RED}$AKS_CLUSTER_NAME${NC}"
echo -e "   🗑️  Container Registry: ${RED}$ACR_NAME${NC}"
echo -e "   🗑️  Resource Group:     ${RED}$RESOURCE_GROUP${NC}"
echo -e "   🗑️  All data and configurations will be lost!"
echo ""

# Double confirmation
echo -e "${YELLOW}This action CANNOT be undone!${NC}"
read -p "Type 'DELETE' to confirm deletion: " CONFIRM

if [[ "$CONFIRM" != "DELETE" ]]; then
    echo -e "${GREEN}✅ Cleanup cancelled - resources are safe${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Cleanup Options${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Choose cleanup level:"
echo "  1) Stop AKS cluster only (saves money, keeps resources)"
echo "  2) Delete AKS cluster only (keeps ACR and resource group)"
echo "  3) Delete everything (complete cleanup)"
echo ""
read -p "Enter your choice (1-3): " CHOICE

case $CHOICE in
    1)
        echo ""
        echo -e "${YELLOW}🛑 Stopping AKS cluster...${NC}"
        az aks stop --name "$AKS_CLUSTER_NAME" --resource-group "$RESOURCE_GROUP"
        echo -e "${GREEN}✅ Cluster stopped (saves ~90% of costs)${NC}"
        echo ""
        echo -e "${CYAN}To restart later:${NC}"
        echo -e "   ${BLUE}az aks start --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP${NC}"
        ;;

    2)
        echo ""
        echo -e "${YELLOW}🗑️  Deleting AKS cluster...${NC}"
        az aks delete \
            --name "$AKS_CLUSTER_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --yes \
            --no-wait
        echo -e "${GREEN}✅ AKS deletion initiated${NC}"
        echo -e "${CYAN}ACR and Resource Group remain (for faster redeployment)${NC}"
        ;;

    3)
        echo ""
        echo -e "${YELLOW}🗑️  Deleting entire resource group...${NC}"
        echo -e "${CYAN}This will delete:${NC}"
        echo -e "   • AKS Cluster"
        echo -e "   • Container Registry"
        echo -e "   • All storage"
        echo -e "   • Load balancers"
        echo -e "   • Network resources"
        echo ""
        read -p "Final confirmation - type 'YES' to proceed: " FINAL_CONFIRM

        if [[ "$FINAL_CONFIRM" == "YES" ]]; then
            az group delete \
                --name "$RESOURCE_GROUP" \
                --yes \
                --no-wait
            echo -e "${GREEN}✅ Resource group deletion initiated${NC}"
            echo -e "${CYAN}All resources will be removed in 5-10 minutes${NC}"
        else
            echo -e "${GREEN}✅ Cleanup cancelled${NC}"
            exit 0
        fi
        ;;

    *)
        echo -e "${RED}❌ Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Verification Commands${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Check deletion status:${NC}"
echo -e "   ${BLUE}az group list --output table${NC}"
echo -e "   ${BLUE}az aks list --output table${NC}"
echo ""
echo -e "${CYAN}If cluster is stopped (option 1), verify:${NC}"
echo -e "   ${BLUE}az aks show --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP --query powerState${NC}"
echo ""
echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo ""
