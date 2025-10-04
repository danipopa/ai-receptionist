# Storage Setup Guide for AI Receptionist

Your FreeSWITCH pod can't start because there's no StorageClass configured. Here are your options:

## Option 1: Use Default Storage Class (Simplest)

If your cluster has a default storage class:

```bash
# Check for default storage class
kubectl get storageclass

# Update FreeSWITCH PVC to use it
kubectl edit pvc freeswitch-data-pvc -n ai-receptionist
# Remove or comment out: storageClassName: local-storage
# Or change to your default storage class name

# Delete and recreate the pod
kubectl delete pod -n ai-receptionist -l app=freeswitch-server
```

## Option 2: Install Local Path Provisioner (Recommended for Single Node)

This creates local storage automatically:

```bash
# Install local-path-provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

# Make it the default
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Update FreeSWITCH PVC
kubectl edit pvc freeswitch-data-pvc -n ai-receptionist
# Change: storageClassName: local-path

# Delete and recreate the pod
kubectl delete pod -n ai-receptionist -l app=freeswitch-server
```

## Option 3: Create Manual PersistentVolume (Quick Fix)

Create a hostPath PV manually:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: freeswitch-data-pv
  labels:
    app: freeswitch
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /var/lib/kubernetes-volumes/freeswitch-data
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ollama-models-pv
  labels:
    app: ollama
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /var/lib/kubernetes-volumes/ollama-models
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ollama-data-pv
  labels:
    app: ollama
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /var/lib/kubernetes-volumes/ollama-data
    type: DirectoryOrCreate
EOF

# Verify PVs are created
kubectl get pv

# Delete and recreate the pod
kubectl delete pod -n ai-receptionist -l app=freeswitch-server
kubectl get pods -n ai-receptionist -w
```

## Option 4: Use EmptyDir (Testing Only - Data Lost on Restart)

For quick testing without persistence:

```bash
# This will lose data on pod restart!
kubectl edit deployment freeswitch-server -n ai-receptionist

# Change the volume from:
#   volumes:
#   - name: freeswitch-data
#     persistentVolumeClaim:
#       claimName: freeswitch-data-pvc
# To:
#   volumes:
#   - name: freeswitch-data
#     emptyDir: {}
```

## Recommended: Option 2 or 3

**For production**: Use Option 2 (local-path-provisioner) - automatic and works well for single-node clusters.

**For quick testing**: Use Option 3 (manual PVs) - simple and direct.

## After Storage is Fixed

Once storage is working, check all PVCs:

```bash
kubectl get pvc -n ai-receptionist
```

You should see:
- freeswitch-data-pvc: Bound
- ollama-models-pvc: Bound (when you deploy Ollama)
- ollama-data-pvc: Bound (when you deploy Ollama)
