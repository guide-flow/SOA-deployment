# Azure Deployment Guide

Complete guide for deploying the SOA application to Azure Kubernetes Service (AKS).

## Prerequisites

1. **Azure Student Account** with active subscription
2. **Azure CLI** installed and logged in
   ```bash
   az login
   az account show  # Verify you're logged into the correct account
   ```
3. **kubectl** installed and configured
4. **Docker Desktop** running locally with all images built

## Cost Estimate

With Azure Student account ($100 free credit):
- **AKS Cluster (B2s x 2 nodes)**: ~$60-70/month
- **Azure Container Registry (Basic)**: ~$5/month
- **Load Balancer**: ~$5/month
- **Storage**: ~$2/month
- **Total**: ~$80-90/month (runs for ~1 month with free credit)

## Deployment Overview

```
Local Machine → Build Images → Push to ACR → Deploy to AKS → Access via Public IP
```

## Step-by-Step Deployment

### 1. Create Azure Resources

```bash
# Set variables (change these to your preferences)
RESOURCE_GROUP="soa-app-rg"
LOCATION="westeurope"  # or your preferred region
ACR_NAME="soacr$(date +%s)"  # Unique ACR name (e.g., soacr1699123456)
AKS_CLUSTER="soa-aks-cluster"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Azure Container Registry
az acr create \
  --name $ACR_NAME \
  --resource-group $RESOURCE_GROUP \
  --sku Basic \
  --location $LOCATION

# Create AKS cluster (2 nodes, cost-optimized for students)
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER \
  --node-count 2 \
  --node-vm-size Standard_B2s \
  --enable-managed-identity \
  --attach-acr $ACR_NAME \
  --generate-ssh-keys \
  --location $LOCATION

# Get AKS credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER

# Verify connection
kubectl get nodes
```

### 2. Build Docker Images (if not already built)

```bash
cd /path/to/SOA

# Build all images
docker-compose -f SOA-deployment/docker-compose.yml build
```

### 3. Push Images to Azure Container Registry

```bash
cd SOA-deployment/scripts

# Make script executable
chmod +x push-to-acr.sh

# Push all images (replace with your ACR name)
./push-to-acr.sh $ACR_NAME

# This will:
# - Login to ACR
# - Tag all images with ACR prefix
# - Push: identity, gateway, frontend, stakeholders, tour, follower-api
```

**Manual alternative** (if script doesn't work):
```bash
az acr login --name $ACR_NAME

docker tag identity:latest $ACR_NAME.azurecr.io/identity:latest
docker push $ACR_NAME.azurecr.io/identity:latest

docker tag gateway:latest $ACR_NAME.azurecr.io/gateway:latest
docker push $ACR_NAME.azurecr.io/gateway:latest

docker tag frontend:latest $ACR_NAME.azurecr.io/frontend:latest
docker push $ACR_NAME.azurecr.io/frontend:latest

docker tag stakeholders:latest $ACR_NAME.azurecr.io/stakeholders:latest
docker push $ACR_NAME.azurecr.io/stakeholders:latest

docker tag tour:latest $ACR_NAME.azurecr.io/tour:latest
docker push $ACR_NAME.azurecr.io/tour:latest

docker tag follower-api:latest $ACR_NAME.azurecr.io/follower-api:latest
docker push $ACR_NAME.azurecr.io/follower-api:latest
```

### 4. Deploy to AKS

```bash
cd SOA-deployment/scripts

# Make script executable
chmod +x deploy-to-aks.sh

# Deploy to AKS (replace with your ACR name)
./deploy-to-aks.sh $ACR_NAME

# This will:
# - Replace {{ACR_NAME}} placeholder in all YAML files
# - Create namespace, secrets, configmaps
# - Create persistent volume claims
# - Deploy databases (PostgreSQL x3, Neo4j, NATS)
# - Deploy application services
```

**Manual alternative** (if script doesn't work):
```bash
cd SOA-deployment/k8s/azure

# Replace ACR_NAME in all files and apply
for file in *.yaml; do
  sed "s/{{ACR_NAME}}/$ACR_NAME/g" "$file" | kubectl apply -f -
done
```

### 5. Monitor Deployment

```bash
# Watch pod status
kubectl get pods -n soa-app --watch

# Check deployment status
kubectl get all -n soa-app

# Check logs if something fails
kubectl logs -n soa-app <pod-name>
kubectl describe pod -n soa-app <pod-name>
```

### 6. Access Your Application

```bash
# Wait for external IP to be assigned (may take 2-5 minutes)
kubectl get services -n soa-app --watch

# Get frontend URL
FRONTEND_IP=$(kubectl get service frontend -n soa-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Frontend URL: http://$FRONTEND_IP:4200"

# Get gateway URL
GATEWAY_IP=$(kubectl get service gateway -n soa-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Gateway URL: http://$GATEWAY_IP:5230"
```

## Troubleshooting

### Pods stuck in "Pending"
```bash
# Check node resources
kubectl describe nodes

# Check PVC status
kubectl get pvc -n soa-app
```

### Image pull errors
```bash
# Verify ACR is attached to AKS
az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --query addonProfiles.azureKeyvaultSecretsProvider

# Reattach ACR if needed
az aks update --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP --attach-acr $ACR_NAME
```

### Neo4j OOMKilled
```bash
# Neo4j needs more memory - already configured with 2Gi limits
# If still failing, increase node size or reduce Neo4j pods
kubectl get events -n soa-app | grep neo4j
```

### Service not getting external IP
```bash
# Check load balancer service
kubectl describe service frontend -n soa-app

# Azure may take 3-5 minutes to provision the Load Balancer
# If stuck after 10 minutes, check Azure Portal → Load Balancers
```

## Key Differences from Local Deployment

| Aspect | Local (Docker Desktop) | Azure (AKS) |
|--------|----------------------|-------------|
| **Image Source** | Local Docker images | Azure Container Registry |
| **Load Balancer** | localhost mapping | Public Azure IP |
| **Storage** | hostPath volumes | Azure Managed Disks |
| **Cost** | Free | ~$80-90/month |
| **Access** | localhost:4200 | http://<EXTERNAL-IP>:4200 |

## Cleanup (IMPORTANT - Avoid Charges!)

When done with testing/presentation:

```bash
# Delete AKS cluster (stops all charges)
az aks delete --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP --yes --no-wait

# Delete ACR
az acr delete --name $ACR_NAME --resource-group $RESOURCE_GROUP --yes

# Delete resource group (deletes everything)
az group delete --name $RESOURCE_GROUP --yes --no-wait

# Verify deletion
az group list --output table
```

## Essential Services for Login Page

If you only need the login functionality, you can skip these services:
- follower-api
- tour
- stakeholders
- neo4j

Just comment out or don't deploy their YAML files.

## Useful Commands

```bash
# Scale deployment
kubectl scale deployment identity -n soa-app --replicas=2

# Restart deployment
kubectl rollout restart deployment identity -n soa-app

# View logs
kubectl logs -f deployment/identity -n soa-app

# Execute into pod
kubectl exec -it <pod-name> -n soa-app -- /bin/bash

# Port forward (for testing without LoadBalancer)
kubectl port-forward service/frontend 4200:4200 -n soa-app
```

## Support

For Azure Student account issues: https://azure.microsoft.com/en-us/free/students/

For AKS documentation: https://learn.microsoft.com/en-us/azure/aks/
