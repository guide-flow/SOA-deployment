#!/bin/bash

# Script to deploy application to Azure Kubernetes Service
# Usage: ./deploy-to-aks.sh <acr-name>

set -e

if [ -z "$1" ]; then
    echo "Error: ACR name not provided"
    echo "Usage: ./deploy-to-aks.sh <acr-name>"
    echo "Example: ./deploy-to-aks.sh myacr123"
    exit 1
fi

ACR_NAME=$1

echo "==============================================="
echo "Azure Kubernetes Service Deployment Script"
echo "==============================================="
echo "ACR Name: $ACR_NAME"
echo "Kubernetes Context: $(kubectl config current-context)"
echo "==============================================="
echo ""

# Navigate to azure deployment folder
cd "$(dirname "$0")/../k8s/azure"

echo "📁 Working directory: $(pwd)"
echo ""

# Create temporary directory for processed files
TEMP_DIR=$(mktemp -d)
echo "📂 Creating temporary directory: $TEMP_DIR"

# Replace ACR_NAME placeholder in all YAML files
echo "🔄 Processing YAML files (replacing {{ACR_NAME}} with $ACR_NAME)..."
for file in *.yaml; do
    sed "s/{{ACR_NAME}}/$ACR_NAME/g" "$file" > "$TEMP_DIR/$file"
    echo "   ✅ Processed: $file"
done

echo ""
echo "==============================================="
echo "🚀 Deploying to Kubernetes..."
echo "==============================================="
echo ""

# Deploy in order
echo "1️⃣  Creating namespace..."
kubectl apply -f "$TEMP_DIR/namespace.yaml"

echo ""
echo "2️⃣  Creating secrets and configmaps..."
kubectl apply -f "$TEMP_DIR/secrets.yaml"
kubectl apply -f "$TEMP_DIR/configmap.yaml"

echo ""
echo "3️⃣  Creating persistent volume claims..."
kubectl apply -f "$TEMP_DIR/pgdata-identity-persistentvolumeclaim.yaml"
kubectl apply -f "$TEMP_DIR/pgdata-stakeholders-persistentvolumeclaim.yaml"
kubectl apply -f "$TEMP_DIR/pgdata-tours-persistentvolumeclaim.yaml"
kubectl apply -f "$TEMP_DIR/neo4j-data-persistentvolumeclaim.yaml"
kubectl apply -f "$TEMP_DIR/neo4j-logs-persistentvolumeclaim.yaml"
kubectl apply -f "$TEMP_DIR/neo4j-import-persistentvolumeclaim.yaml"
kubectl apply -f "$TEMP_DIR/neo4j-plugins-persistentvolumeclaim.yaml"

echo ""
echo "4️⃣  Deploying databases..."
kubectl apply -f "$TEMP_DIR/postgres-identity-deployment.yaml"
kubectl apply -f "$TEMP_DIR/postgres_identity-service.yaml"
kubectl apply -f "$TEMP_DIR/postgres-stakeholders-deployment.yaml"
kubectl apply -f "$TEMP_DIR/postgres_stakeholders-service.yaml"
kubectl apply -f "$TEMP_DIR/postgres-tours-deployment.yaml"
kubectl apply -f "$TEMP_DIR/postgres_tours-service.yaml"
kubectl apply -f "$TEMP_DIR/neo4j-deployment.yaml"
kubectl apply -f "$TEMP_DIR/neo4j-service.yaml"
kubectl apply -f "$TEMP_DIR/nats-deployment.yaml"
kubectl apply -f "$TEMP_DIR/nats-service.yaml"

echo ""
echo "5️⃣  Deploying application services..."
kubectl apply -f "$TEMP_DIR/identity-deployment.yaml"
kubectl apply -f "$TEMP_DIR/identity-service.yaml"
kubectl apply -f "$TEMP_DIR/stakeholders-deployment.yaml"
kubectl apply -f "$TEMP_DIR/stakeholders-service.yaml"
kubectl apply -f "$TEMP_DIR/tour-deployment.yaml"
kubectl apply -f "$TEMP_DIR/tour-service.yaml"
kubectl apply -f "$TEMP_DIR/follower-api-deployment.yaml"
kubectl apply -f "$TEMP_DIR/follower-api-service.yaml"
kubectl apply -f "$TEMP_DIR/gateway-deployment.yaml"
kubectl apply -f "$TEMP_DIR/gateway-service.yaml"
kubectl apply -f "$TEMP_DIR/frontend-deployment.yaml"
kubectl apply -f "$TEMP_DIR/frontend-service.yaml"

echo ""
echo "🧹 Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo ""
echo "==============================================="
echo "✅ Deployment Complete!"
echo "==============================================="
echo ""
echo "📊 Checking deployment status..."
kubectl get pods -n soa-app

echo ""
echo "🌐 Getting service external IPs (this may take a few minutes)..."
echo "Run this command to check when IPs are assigned:"
echo "   kubectl get services -n soa-app --watch"
echo ""
echo "To get the frontend URL:"
echo "   kubectl get service frontend -n soa-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
