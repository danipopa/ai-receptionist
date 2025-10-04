# FreeSWITCH Architecture - Updated

## Overview

The FreeSWITCH component has been split into two separate services for better separation of concerns:

1. **`freeswitch-server`** - The core FreeSWITCH telephony server
2. **`ai-freeswitch`** - Python integration layer connecting FreeSWITCH to AI services

## Components

### 1. FreeSWITCH Server (`freeswitch-server`)

**Purpose:** Core SIP/RTP telephony server

**Image:** `176.9.65.80:5000/ai-receptionist/freeswitch-server:latest`

**Key Features:**
- Built using SignalWire's official FreeSWITCH packages
- Handles all SIP signaling and RTP media
- Exposes Event Socket Layer (ESL) on port 8021
- Includes essential modules: SIP, codecs, Lua, dialplan, etc.

**Ports:**
- `5060/UDP` - SIP signaling
- `8021/TCP` - Event Socket Layer (for ai-freeswitch to connect)
- `16384-32768/UDP` - RTP media range

**Services:**
- `freeswitch-sip` (LoadBalancer) - External SIP access
- `freeswitch-rtp` (LoadBalancer) - External RTP access
- `freeswitch-event-socket` (ClusterIP) - Internal ESL access for ai-freeswitch
- `freeswitch-headless` (Headless) - Pod discovery

**Storage:**
- `/etc/freeswitch` - Configuration files
- `/var/log/freeswitch` - Log files
- `/var/lib/freeswitch` - Runtime data (PVC-backed)

---

### 2. AI-FreeSWITCH Integration (`ai-freeswitch`)

**Purpose:** Python service that bridges FreeSWITCH with AI Engine and Backend API

**Image:** `176.9.65.80:5000/ai-receptionist/ai-freeswitch:latest`

**Key Features:**
- Connects to FreeSWITCH via Event Socket Layer (ESL)
- Processes call events and routes to AI Engine
- Manages call state and logging
- Provides HTTP API for monitoring and control

**Ports:**
- `8080/TCP` - HTTP API for health checks and management

**Environment Variables:**
- `FREESWITCH_HOST=freeswitch-event-socket` - FreeSWITCH ESL service
- `FREESWITCH_PORT=8021` - ESL port
- `FREESWITCH_PASSWORD=ClueCon` - ESL authentication
- `AI_ENGINE_URL=http://ai-engine:8000` - AI service
- `BACKEND_API_URL=http://backend-ai-receptionist:3000/api/v1` - Backend API

**Services:**
- `ai-freeswitch` (ClusterIP) - HTTP API access

---

## Communication Flow

```
Incoming Call
     ↓
[SIP Provider] → (5060/UDP) → [freeswitch-server]
                                      ↓
                              (Event Socket Layer - 8021/TCP)
                                      ↓
                               [ai-freeswitch]
                                      ↓
                              ┌──────┴──────┐
                              ↓             ↓
                        [ai-engine]  [backend-api]
                         (OpenAI)    (Rails/MySQL)
```

## Deployment Order

1. Deploy FreeSWITCH Server first:
   ```bash
   kubectl apply -f k8s-manifests/freeswitch/deployment.yaml
   kubectl apply -f k8s-manifests/freeswitch/service.yaml
   ```

2. Verify FreeSWITCH is running:
   ```bash
   kubectl get pods -n ai-receptionist -l app=freeswitch-server
   kubectl logs -n ai-receptionist -l app=freeswitch-server
   ```

3. Deploy AI-FreeSWITCH Integration:
   ```bash
   kubectl apply -f k8s-manifests/ai-freeswitch/deployment.yaml
   kubectl apply -f k8s-manifests/ai-freeswitch/service.yaml
   ```

4. Verify Integration:
   ```bash
   kubectl get pods -n ai-receptionist -l app=ai-freeswitch
   kubectl logs -n ai-receptionist -l app=ai-freeswitch
   ```

## Key Changes from Previous Setup

### What Changed:
- ❌ **Removed:** HTTP health checks on port 8080 from freeswitch-server (not available in pure FreeSWITCH)
- ✅ **Added:** TCP health checks on Event Socket Layer (8021)
- ✅ **Added:** Separate `ai-freeswitch` deployment for Python integration
- ✅ **Changed:** Service name from `freeswitch-api` to `freeswitch-event-socket`
- ✅ **Changed:** App label from `freeswitch` to `freeswitch-server`
- ✅ **Simplified:** No longer building from source, using SignalWire packages

### What Stayed the Same:
- SIP and RTP ports (5060, 16384-32768)
- External LoadBalancer setup with MetalLB
- Storage configuration
- Resource limits

## Configuration Notes

### FreeSWITCH Server
- Currently uses default FreeSWITCH configuration
- To customize: create a ConfigMap and mount to `/etc/freeswitch`
- Default ESL password is `ClueCon` (should be changed in production)

### AI-FreeSWITCH
- Connects to FreeSWITCH using `freeswitch-event-socket` service
- HTTP API available for health checks and monitoring
- Logs call events and routes to AI engine

## Security Considerations

1. **ESL Password:** Change the default `ClueCon` password
2. **Network Policies:** Consider adding NetworkPolicies to restrict ESL access
3. **Token Management:** SignalWire token is in Dockerfile (move to secrets)

## Troubleshooting

### Check FreeSWITCH Server Status
```bash
# Check if FreeSWITCH is running
kubectl exec -it -n ai-receptionist deployment/freeswitch-server -- fs_cli -x "status"

# Check active calls
kubectl exec -it -n ai-receptionist deployment/freeswitch-server -- fs_cli -x "show calls"

# View FreeSWITCH logs
kubectl logs -n ai-receptionist -l app=freeswitch-server -f
```

### Check AI-FreeSWITCH Integration
```bash
# Check if connected to FreeSWITCH
kubectl logs -n ai-receptionist -l app=ai-freeswitch | grep -i "connected"

# Check health endpoint
kubectl port-forward -n ai-receptionist deployment/ai-freeswitch 8080:8080
curl http://localhost:8080/health
```

### Common Issues

**Issue:** ai-freeswitch can't connect to FreeSWITCH
- **Check:** Ensure freeswitch-server pod is running
- **Check:** Verify Event Socket is enabled in FreeSWITCH config
- **Check:** Confirm password matches between services

**Issue:** No audio during calls
- **Check:** RTP ports (16384-32768) are properly exposed
- **Check:** LoadBalancer IP is accessible externally
- **Check:** NAT/firewall settings on your network

## Next Steps

1. ✅ FreeSWITCH server built and pushed to registry
2. ✅ Kubernetes manifests updated for new architecture
3. ⏳ Deploy updated manifests to cluster
4. ⏳ Test call flow end-to-end
5. ⏳ Configure FreeSWITCH dialplan for AI integration
6. ⏳ Add custom FreeSWITCH configuration via ConfigMap
