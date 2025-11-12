# Azure Deployment Scripts

Automated scripts for deploying the SOA Tourism Application to Azure Kubernetes Service (AKS).

## 📋 Prerequisites

- **Azure CLI** installed and logged in (`az login`)
- **kubectl** installed
- **helm** installed
- **Docker Desktop** running
- **Azure Student Account** or any Azure subscription

## 🚀 Quick Start

### 1. Configure Deployment

Edit `config.env` and set your preferences:

```bash
RESOURCE_GROUP="soa-rg"
LOCATION="swedencentral"
ACR_NAME="soathesisregistryserbia"
AKS_CLUSTER_NAME="soa-aks-cluster"
DNS_NAME="soa-app-thesis"  # Optional
```

### 2. Run Deployment Scripts

Run scripts in order:

```bash
# Step 1: Create Azure resources (RG, ACR, AKS)
./1-create-azure-resources.sh

# Step 2: Build and push Docker images
./2-build-and-push-images.sh

# Step 3: Deploy to AKS
./3-deploy-to-aks.sh

# Step 4: Setup Ingress (optional but recommended)
./4-setup-ingress.sh
```

### 3. Access Your Application

After deployment completes:

**With Ingress + DNS:**
- Frontend: `http://soa-app-thesis.swedencentral.cloudapp.azure.com`
- Gateway: `http://soa-app-thesis.swedencentral.cloudapp.azure.com/api`

**Without Ingress:**
- Get IPs: `kubectl get services -n soa-app`
- Frontend: `http://<FRONTEND-IP>:4200`
- Gateway: `http://<GATEWAY-IP>:5230`

## 📝 Script Descriptions

### `config.env`
Central configuration file. Edit this to customize your deployment.

### `1-create-azure-resources.sh`
- Creates Resource Group
- Creates Azure Container Registry (ACR)
- Creates AKS cluster with 2 nodes
- Configures kubectl context
- **Time:** ~5-10 minutes

### `2-build-and-push-images.sh`
- Builds all Docker images using docker-compose
- Tags images for ACR
- Pushes to Azure Container Registry
- **Time:** ~5-10 minutes (depends on internet speed)

### `3-deploy-to-aks.sh`
- Deploys namespace, secrets, configmaps
- Creates persistent volume claims
- Deploys databases (PostgreSQL x3, Neo4j, NATS)
- Deploys microservices (identity, stakeholders, followers, tours, gateway, frontend)
- Waits for pods to be ready
- **Time:** ~3-5 minutes

### `4-setup-ingress.sh`
- Installs NGINX Ingress Controller
- Configures Azure Load Balancer
- Sets up DNS name (if configured)
- Applies ingress rules
- **Time:** ~2-3 minutes

### `cleanup-azure.sh`
- **Option 1:** Stop cluster (saves money, keeps resources)
- **Option 2:** Delete cluster only (keeps ACR)
- **Option 3:** Delete everything (complete cleanup)

## 💰 Cost Management

### Estimated Costs
- **AKS Cluster:** ~$0.10/hour (~$2.40/day)
- **ACR Basic:** ~$5/month
- **Load Balancer:** ~$0.025/hour
- **Storage:** ~$0.05/GB/month

### Save Money

**Stop cluster when not in use:**
```bash
az aks stop --name soa-aks-cluster --resource-group soa-rg
```

**Restart when needed:**
```bash
az aks start --name soa-aks-cluster --resource-group soa-rg
```

**Delete everything:**
```bash
./cleanup-azure.sh
```

## 🔍 Useful Commands

### Monitor Deployment
```bash
# Watch pods starting
kubectl get pods -n soa-app -w

# Get all services
kubectl get services -n soa-app

# Check ingress
kubectl get ingress -n soa-app
```

### Check Logs
```bash
# View logs for a service
kubectl logs -n soa-app deployment/identity

# Follow logs
kubectl logs -n soa-app deployment/gateway -f
```

### Describe Resources
```bash
# Describe pod (useful for troubleshooting)
kubectl describe pod -n soa-app <pod-name>

# Describe service
kubectl describe service -n soa-app frontend
```

### Scale Cluster
```bash
# Scale to 3 nodes
az aks scale --resource-group soa-rg --name soa-aks-cluster --node-count 3

# Restart all deployments
kubectl rollout restart deployment -n soa-app
```

## 🐛 Troubleshooting

### Pods stuck in "Pending"
```bash
# Check events
kubectl get events -n soa-app --sort-by='.lastTimestamp'

# Check node resources
kubectl describe nodes
```

### ImagePullBackOff errors
```bash
# Verify ACR is attached to AKS
az aks update --name soa-aks-cluster --resource-group soa-rg --attach-acr soathesisregistryserbia

# Check ACR images
az acr repository list --name soathesisregistryserbia --output table
```

### Service not getting external IP
```bash
# Wait 2-5 minutes, then check
kubectl get services -n soa-app --watch

# Check Azure Portal → Load Balancers if stuck after 10 minutes
```

### Neo4j OOMKilled
```bash
# Already configured with 2Gi limits
# If still failing, check events
kubectl describe pod -n soa-app <neo4j-pod-name>

# May need to increase node size or reduce Neo4j memory
```

## 📚 Additional Resources

- [Azure AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [NGINX Ingress Documentation](https://kubernetes.github.io/ingress-nginx/)

## ⚠️ Important Notes

1. **GitHub Actions:** If you have CI/CD set up, pushing to GitHub will automatically build and deploy
2. **First Deployment:** Always run scripts in order (1 → 2 → 3 → 4)
3. **Subsequent Deployments:** If resources exist, you can skip step 1
4. **Frontend URLs:** Frontend uses relative URLs (`'api/'`) so no rebuild needed for different environments
5. **Cost Reminder:** Always stop or delete resources when not in use!

## 🆘 Need Help?

If you encounter issues:
1. Check the troubleshooting section above
2. Review logs with `kubectl logs`
3. Check Azure Portal for resource status
4. Verify kubectl context: `kubectl config current-context`
