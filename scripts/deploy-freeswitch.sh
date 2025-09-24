#!/bin/bash

# Set variables
DOCKER_IMAGE="176.9.65.80/freeswitch:latest"
NAMESPACE="freeswitch"

# Create the namespace if it doesn't exist
kubectl get namespace $NAMESPACE || kubectl create namespace $NAMESPACE

# Apply the Kubernetes configurations
kubectl apply -f ../k8s/namespace.yaml -n $NAMESPACE
kubectl apply -f ../k8s/configmap.yaml -n $NAMESPACE
kubectl apply -f ../k8s/persistentvolume.yaml -n $NAMESPACE
kubectl apply -f ../k8s/persistentvolumeclaim.yaml -n $NAMESPACE
kubectl apply -f ../k8s/deployment.yaml -n $NAMESPACE
kubectl apply -f ../k8s/service.yaml -n $NAMESPACE

# Wait for the deployment to be ready
kubectl rollout status deployment/freeswitch -n $NAMESPACE

echo "FreeSWITCH deployment completed successfully."