#!/bin/bash

# ===================================================================
# Setup NGINX Ingress Controller with Optional DNS
# ===================================================================
# Installs NGINX Ingress Controller and configures DNS hostname
# ===================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# Navigate to K8s manifests directory
MANIFESTS_DIR="$(cd "$SCRIPT_DIR/$K8S_MANIFESTS_PATH" && pwd)"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Setup NGINX Ingress Controller                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$ENABLE_INGRESS" != "true" ]]; then
    echo -e "${YELLOW}⚠️  Ingress is disabled in config.env${NC}"
    echo -e "Set ENABLE_INGRESS=\"true\" to enable ingress setup"
    exit 0
fi

echo -e "${BLUE}📋 Configuration:${NC}"
echo -e "   Namespace:     ${GREEN}$NAMESPACE${NC}"
echo -e "   DNS Name:      ${GREEN}${DNS_NAME:-Not configured}${NC}"
echo -e "   Location:      ${GREEN}$LOCATION${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 1: Add NGINX Ingress Helm Repository${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}📝 Adding Helm repository...${NC}"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
echo -e "${GREEN}✅ Helm repository added${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 2: Installing NGINX Ingress Controller${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if kubectl get namespace ingress-nginx &>/dev/null; then
    echo -e "${YELLOW}⚡ Ingress-nginx namespace already exists${NC}"
else
    echo -e "${YELLOW}⏳ Installing NGINX Ingress Controller...${NC}"
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
    echo -e "${GREEN}✅ NGINX Ingress Controller installed${NC}"
fi
echo ""

echo -e "${YELLOW}⏳ Waiting for Ingress controller to be ready...${NC}"
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s
echo -e "${GREEN}✅ Ingress controller is ready${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 3: Getting Ingress Controller External IP${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}⏳ Waiting for external IP assignment (may take 2-3 minutes)...${NC}"

# Wait for external IP
EXTERNAL_IP=""
COUNTER=0
MAX_ATTEMPTS=30

while [ -z "$EXTERNAL_IP" ] && [ $COUNTER -lt $MAX_ATTEMPTS ]; do
    EXTERNAL_IP=$(kubectl get service ingress-nginx-controller \
        --namespace ingress-nginx \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

    if [ -z "$EXTERNAL_IP" ]; then
        echo -e "${YELLOW}   ⏳ Waiting for IP... (attempt $((COUNTER+1))/$MAX_ATTEMPTS)${NC}"
        sleep 10
        COUNTER=$((COUNTER+1))
    fi
done

if [ -z "$EXTERNAL_IP" ]; then
    echo -e "${RED}❌ Failed to get external IP after $MAX_ATTEMPTS attempts${NC}"
    echo -e "${YELLOW}Check the service status:${NC}"
    kubectl get service ingress-nginx-controller --namespace ingress-nginx
    exit 1
fi

echo -e "${GREEN}✅ External IP assigned: $EXTERNAL_IP${NC}"
echo ""

# Configure DNS if DNS_NAME is provided
if [ -n "$DNS_NAME" ]; then
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE} Step 4: Configuring DNS Name${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

    echo -e "${YELLOW}🔍 Finding Public IP resource...${NC}"

    # Get the resource group for AKS infrastructure (starts with MC_)
    INFRA_RG=$(az aks show --name "$AKS_CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --query nodeResourceGroup -o tsv)
    echo -e "   Infrastructure RG: ${GREEN}$INFRA_RG${NC}"

    # Find the public IP name
    PUBLIC_IP_NAME=$(az network public-ip list --resource-group "$INFRA_RG" --query "[?ipAddress=='$EXTERNAL_IP'].name" -o tsv)

    if [ -z "$PUBLIC_IP_NAME" ]; then
        echo -e "${YELLOW}⚠️  Could not find Public IP resource automatically${NC}"
        echo -e "${YELLOW}Listing all public IPs in $INFRA_RG:${NC}"
        az network public-ip list --resource-group "$INFRA_RG" --output table
        echo ""
        echo -e "${YELLOW}Manual DNS setup:${NC}"
        echo -e "   Find the IP with address: ${GREEN}$EXTERNAL_IP${NC}"
        echo -e "   Then run: ${BLUE}az network public-ip update --resource-group $INFRA_RG --name <IP-NAME> --dns-name $DNS_NAME${NC}"
    else
        echo -e "   Public IP Name: ${GREEN}$PUBLIC_IP_NAME${NC}"
        echo ""
        echo -e "${YELLOW}🌐 Configuring DNS name: $DNS_NAME...${NC}"
        az network public-ip update \
            --resource-group "$INFRA_RG" \
            --name "$PUBLIC_IP_NAME" \
            --dns-name "$DNS_NAME"

        FQDN="${DNS_NAME}.${LOCATION}.cloudapp.azure.com"
        echo -e "${GREEN}✅ DNS configured${NC}"
        echo -e "   FQDN: ${GREEN}$FQDN${NC}"
    fi
    echo ""
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 5: Applying Ingress Rules${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if [ -f "$MANIFESTS_DIR/ingress.yaml" ]; then
    echo -e "${YELLOW}📄 Applying ingress.yaml...${NC}"

    # If DNS is configured, update ingress to use FQDN
    if [ -n "$DNS_NAME" ] && [ -n "$FQDN" ]; then
        TEMP_INGRESS=$(mktemp)
        sed "s/{{FQDN}}/$FQDN/g" "$MANIFESTS_DIR/ingress.yaml" > "$TEMP_INGRESS"
        kubectl apply -f "$TEMP_INGRESS"
        rm "$TEMP_INGRESS"
    else
        kubectl apply -f "$MANIFESTS_DIR/ingress.yaml"
    fi

    echo -e "${GREEN}✅ Ingress rules applied${NC}"
else
    echo -e "${YELLOW}⚠️  ingress.yaml not found at $MANIFESTS_DIR${NC}"
    echo -e "${YELLOW}Skipping ingress rules application${NC}"
fi
echo ""

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Ingress Controller Setup Complete!                   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}📊 Ingress Information:${NC}"
echo -e "   External IP:    ${GREEN}$EXTERNAL_IP${NC}"

if [ -n "$DNS_NAME" ] && [ -n "$FQDN" ]; then
    echo -e "   DNS Name:       ${GREEN}$FQDN${NC}"
    echo -e "   Frontend URL:   ${GREEN}http://$FQDN${NC}"
    echo -e "   Gateway URL:    ${GREEN}http://$FQDN/api${NC}"
else
    echo -e "   Frontend URL:   ${GREEN}http://$EXTERNAL_IP${NC}"
    echo -e "   Gateway URL:    ${GREEN}http://$EXTERNAL_IP/api${NC}"
fi
echo ""

echo -e "${YELLOW}📝 Next Steps:${NC}"
if [ -n "$DNS_NAME" ] && [ -n "$FQDN" ]; then
    echo -e "   1️⃣  Update frontend configuration with DNS URL:"
    echo -e "      ${BLUE}./5-configure-frontend.sh${NC}"
    echo ""
    echo -e "   2️⃣  Or manually update frontend environment:"
    echo -e "      ${CYAN}gatewayHost: 'http://$FQDN/api/'${NC}"
else
    echo -e "   1️⃣  Update frontend configuration with IP address"
    echo -e "   2️⃣  Or configure a DNS name and re-run this script"
fi
echo ""

echo -e "${CYAN}🔍 Useful Commands:${NC}"
echo -e "   Check ingress status: ${BLUE}kubectl get ingress -n $NAMESPACE${NC}"
echo -e "   Check ingress events:  ${BLUE}kubectl describe ingress -n $NAMESPACE${NC}"
echo -e "   View ingress logs:     ${BLUE}kubectl logs -n ingress-nginx deployment/ingress-nginx-controller${NC}"
echo ""
