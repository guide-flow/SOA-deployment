#!/bin/bash

# ===================================================================
# Deploy Application to Azure Kubernetes Service
# ===================================================================
# Deploys all Kubernetes manifests to AKS cluster
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
echo -e "${BLUE}║        Deploy to Azure Kubernetes Service                ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}📋 Configuration:${NC}"
echo -e "   ACR Name:          ${GREEN}$ACR_NAME${NC}"
echo -e "   Namespace:         ${GREEN}$NAMESPACE${NC}"
echo -e "   Manifests Dir:     ${GREEN}$MANIFESTS_DIR${NC}"
echo -e "   Kubectl Context:   ${GREEN}$(kubectl config current-context)${NC}"
echo ""

# Verify we're connected to correct cluster
echo -e "${YELLOW}🔍 Verifying cluster connection...${NC}"
if ! kubectl get nodes &>/dev/null; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster!${NC}"
    echo -e "${YELLOW}Please run: az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Connected to cluster${NC}"
echo ""

# Create temporary directory for processed files
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}📂 Creating temporary directory: $TEMP_DIR${NC}"

# Replace ACR_NAME placeholder in all YAML files
echo -e "${YELLOW}🔄 Processing YAML files (replacing {{ACR_NAME}} with $ACR_NAME)...${NC}"
for file in "$MANIFESTS_DIR"/*.yaml; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        sed "s/{{ACR_NAME}}/$ACR_NAME/g" "$file" > "$TEMP_DIR/$filename"
        echo -e "   ${CYAN}✓${NC} Processed: $filename"
    fi
done
echo -e "${GREEN}✅ All files processed${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 1: Creating Namespace${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}⚡ Namespace '$NAMESPACE' already exists${NC}"
else
    kubectl apply -f "$TEMP_DIR/namespace.yaml"
    echo -e "${GREEN}✅ Namespace created${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 2: Creating Secrets and ConfigMaps${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

kubectl apply -f "$TEMP_DIR/secrets.yaml"
echo -e "${GREEN}✅ Secrets created${NC}"

kubectl apply -f "$TEMP_DIR/configmap.yaml"
echo -e "${GREEN}✅ ConfigMap created${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 3: Creating Persistent Volume Claims${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}📦 Creating PVCs for PostgreSQL databases...${NC}"
kubectl apply -f "$TEMP_DIR/pgdata-identity-persistentvolumeclaim.yaml"
kubectl apply -f "$TEMP_DIR/pgdata-stakeholders-persistentvolumeclaim.yaml"
kubectl apply -f "$TEMP_DIR/pgdata-tours-persistentvolumeclaim.yaml"

echo -e "${YELLOW}📦 Creating PVCs for Neo4j...${NC}"
kubectl apply -f "$TEMP_DIR/neo4j-data-persistentvolumeclaim.yaml"
kubectl apply -f "$TEMP_DIR/neo4j-logs-persistentvolumeclaim.yaml"
kubectl apply -f "$TEMP_DIR/neo4j-import-persistentvolumeclaim.yaml"
kubectl apply -f "$TEMP_DIR/neo4j-plugins-persistentvolumeclaim.yaml"

# Check if stakeholders images PVC exists
if [ -f "$TEMP_DIR/stakeholders-images-persistentvolumeclaim.yaml" ]; then
    echo -e "${YELLOW}📦 Creating PVC for stakeholders images...${NC}"
    kubectl apply -f "$TEMP_DIR/stakeholders-images-persistentvolumeclaim.yaml"
fi

echo -e "${GREEN}✅ All PVCs created${NC}"

# Wait for PVCs to be bound
echo -e "${YELLOW}⏳ Waiting for PVCs to be bound...${NC}"
sleep 5
kubectl get pvc -n "$NAMESPACE"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 4: Deploying Databases${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}🐘 Deploying PostgreSQL databases...${NC}"
kubectl apply -f "$TEMP_DIR/postgres-identity-deployment.yaml"
kubectl apply -f "$TEMP_DIR/postgres_identity-service.yaml"
kubectl apply -f "$TEMP_DIR/postgres-stakeholders-deployment.yaml"
kubectl apply -f "$TEMP_DIR/postgres_stakeholders-service.yaml"
kubectl apply -f "$TEMP_DIR/postgres-tours-deployment.yaml"
kubectl apply -f "$TEMP_DIR/postgres_tours-service.yaml"

echo -e "${YELLOW}🔴 Deploying Neo4j...${NC}"
kubectl apply -f "$TEMP_DIR/neo4j-deployment.yaml"
kubectl apply -f "$TEMP_DIR/neo4j-service.yaml"

echo -e "${YELLOW}📨 Deploying NATS...${NC}"
kubectl apply -f "$TEMP_DIR/nats-deployment.yaml"
kubectl apply -f "$TEMP_DIR/nats-service.yaml"

echo -e "${GREEN}✅ Databases deployed${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 5: Deploying Application Services${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}🔐 Deploying Identity service...${NC}"
kubectl apply -f "$TEMP_DIR/identity-deployment.yaml"
kubectl apply -f "$TEMP_DIR/identity-service.yaml"

echo -e "${YELLOW}👥 Deploying Stakeholders service...${NC}"
kubectl apply -f "$TEMP_DIR/stakeholders-deployment.yaml"
kubectl apply -f "$TEMP_DIR/stakeholders-service.yaml"

echo -e "${YELLOW}🚶 Deploying Follower API...${NC}"
kubectl apply -f "$TEMP_DIR/follower-api-deployment.yaml"
kubectl apply -f "$TEMP_DIR/follower-api-service.yaml"

echo -e "${YELLOW}🗺️  Deploying Tour service...${NC}"
kubectl apply -f "$TEMP_DIR/tour-deployment.yaml"
kubectl apply -f "$TEMP_DIR/tour-service.yaml"

echo -e "${YELLOW}🌐 Deploying Gateway...${NC}"
kubectl apply -f "$TEMP_DIR/gateway-deployment.yaml"
kubectl apply -f "$TEMP_DIR/gateway-service.yaml"

echo -e "${YELLOW}🎨 Deploying Frontend...${NC}"
kubectl apply -f "$TEMP_DIR/frontend-deployment.yaml"
kubectl apply -f "$TEMP_DIR/frontend-service.yaml"

echo -e "${GREEN}✅ All services deployed${NC}"
echo ""

# Cleanup temporary files
echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -rf "$TEMP_DIR"
echo -e "${GREEN}✅ Cleanup complete${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Step 6: Monitoring Deployment${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}📊 Current pod status:${NC}"
kubectl get pods -n "$NAMESPACE"
echo ""

if [[ "$WAIT_FOR_READY" == "true" ]]; then
    echo -e "${YELLOW}⏳ Waiting for pods to be ready (timeout: ${MAX_WAIT_TIME}s)...${NC}"
    echo -e "${CYAN}💡 This may take 2-5 minutes for all pods to start${NC}"
    echo ""

    # Wait for deployments to be ready
    if timeout "$MAX_WAIT_TIME" kubectl wait --for=condition=ready pod --all -n "$NAMESPACE" --timeout="${MAX_WAIT_TIME}s" 2>/dev/null; then
        echo -e "${GREEN}✅ All pods are ready!${NC}"
    else
        echo -e "${YELLOW}⚠️  Some pods are still starting. Check status with:${NC}"
        echo -e "   ${BLUE}kubectl get pods -n $NAMESPACE -w${NC}"
    fi
    echo ""
fi

echo -e "${YELLOW}📊 Final pod status:${NC}"
kubectl get pods -n "$NAMESPACE"
echo ""

echo -e "${YELLOW}🌐 Services status:${NC}"
kubectl get services -n "$NAMESPACE"
echo ""

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Deployment Complete!                                 ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}📝 Next Steps:${NC}"

# Check if services have LoadBalancer type
FRONTEND_TYPE=$(kubectl get service frontend -n "$NAMESPACE" -o jsonpath='{.spec.type}' 2>/dev/null || echo "")
GATEWAY_TYPE=$(kubectl get service gateway -n "$NAMESPACE" -o jsonpath='{.spec.type}' 2>/dev/null || echo "")

if [[ "$FRONTEND_TYPE" == "LoadBalancer" ]] || [[ "$GATEWAY_TYPE" == "LoadBalancer" ]]; then
    echo -e "   1️⃣  Wait for external IPs (may take 2-5 minutes):"
    echo -e "      ${BLUE}kubectl get services -n $NAMESPACE --watch${NC}"
    echo ""
    echo -e "   2️⃣  Get frontend URL:"
    echo -e "      ${BLUE}kubectl get service frontend -n $NAMESPACE${NC}"
    echo ""
else
    echo -e "   1️⃣  Setup Ingress controller:"
    echo -e "      ${BLUE}./4-setup-ingress.sh${NC}"
    echo ""
fi

echo -e "${CYAN}🔍 Useful Commands:${NC}"
echo -e "   Monitor pods:     ${BLUE}kubectl get pods -n $NAMESPACE -w${NC}"
echo -e "   Check logs:       ${BLUE}kubectl logs -n $NAMESPACE deployment/<service-name>${NC}"
echo -e "   Describe pod:     ${BLUE}kubectl describe pod -n $NAMESPACE <pod-name>${NC}"
echo -e "   Get all services: ${BLUE}kubectl get services -n $NAMESPACE${NC}"
echo ""
