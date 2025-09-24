#!/bin/bash

# Cleanup script for FreeSWITCH Kubernetes deployment

# Set the namespace variable
NAMESPACE="freeswitch"

# Delete the deployment
kubectl delete deployment freeswitch --namespace=$NAMESPACE

# Delete the service
kubectl delete service freeswitch --namespace=$NAMESPACE

# Delete the persistent volume claim
kubectl delete pvc freeswitch-pvc --namespace=$NAMESPACE

# Delete the config map
kubectl delete configmap freeswitch-config --namespace=$NAMESPACE

# Optionally, delete the namespace if no longer needed
# kubectl delete namespace $NAMESPACE

echo "Cleanup completed."