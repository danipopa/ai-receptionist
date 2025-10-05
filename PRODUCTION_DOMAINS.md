# Production Domain Configuration

## 🌐 **Production Domains**

### **Frontend Application**
- **Domain**: `frontmind.mobiletel.eu`
- **URL**: `https://frontmind.mobiletel.eu`
- **Service**: Frontend Nuxt.js application
- **Port**: 443 (HTTPS)
- **Ingress**: `k8s-manifests/tls-frontmind.mobiletel.eu/ingress-frontmind.yaml`
- **TLS Certificate**: `frontmind-tls` (Let's Encrypt)

### **Backend API**
- **Domain**: `api.frontmind.mobiletel.eu`
- **URL**: `https://api.frontmind.mobiletel.eu`
- **Service**: Backend Rails API
- **Port**: 443 (HTTPS)
- **Ingress**: `k8s-manifests/tls-api.frontmind.mobiletel.eu/ingress-api.yaml`
- **TLS Certificate**: `api-frontmind-tls` (Let's Encrypt)

## 🔧 **Configuration Files**

### **Environment Variables**
- **Main Config**: `.env`
- **Frontend Config**: `frontend-ai-receptionist/.env`
- **Backend Environment**: Configured via Kubernetes deployment manifests

### **API Configuration**
- **API Base URL**: `https://api.frontmind.mobiletel.eu/api/v1`
- **API Authentication**: `frontend-production-key-2024`
- **CORS Origin**: `https://frontmind.mobiletel.eu`

### **Docker Images**
- **Frontend**: `176.9.65.80:5000/ai-receptionist/frontend-ai-receptionist:latest`
- **Backend**: `176.9.65.80:5000/ai-receptionist/backend-ai-receptionist:latest`

## 🚀 **Deployment Commands**

### **Deploy Frontend**
```bash
kubectl apply -f k8s-manifests/tls-frontmind.mobiletel.eu/
kubectl apply -f k8s-manifests/frontend/
```

### **Deploy Backend API**
```bash
kubectl apply -f k8s-manifests/tls-api.frontmind.mobiletel.eu/
kubectl apply -f k8s-manifests/backend/
```

### **Check Status**
```bash
kubectl get ingress -n ai-receptionist
kubectl get certificates -n ai-receptionist
kubectl get pods -n ai-receptionist
```

## 📋 **Key Features**
- ✅ **Let's Encrypt TLS certificates** for HTTPS
- ✅ **CORS configuration** for frontend-backend communication  
- ✅ **API key authentication** between services
- ✅ **SIP authentication framework** for FreeSWITCH integration
- ✅ **Production-ready Docker images** in private registry

## 🔐 **Security Configuration**
- **API Authentication**: Required for all backend API calls
- **HTTPS Enforcement**: SSL redirect enabled on both domains
- **CORS Policy**: Restricted to production frontend domain
- **SIP Authentication**: Customer-based credentials for telephony

---
**Last Updated**: October 5, 2025
**Environment**: Production
**Status**: ✅ Ready for deployment