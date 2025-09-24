#!/bin/bash

# Storage setup script for AI Receptionist Kubernetes deployment
# This script creates the necessary storage directories on the Kubernetes node

set -e

STORAGE_BASE="/home/storage/ns/ai-receptionist"

echo "Setting up storage directories for AI Receptionist..."

# Create base directory
sudo mkdir -p "$STORAGE_BASE"

# Create specific directories for each service
echo "Creating MySQL storage directory..."
sudo mkdir -p "$STORAGE_BASE/mysql"
sudo chown 999:999 "$STORAGE_BASE/mysql"  # MySQL runs as user 999 in container
sudo chmod 755 "$STORAGE_BASE/mysql"

echo "Creating Redis storage directory..."
sudo mkdir -p "$STORAGE_BASE/redis"
sudo chown 999:999 "$STORAGE_BASE/redis"  # Redis runs as user 999 in container
sudo chmod 755 "$STORAGE_BASE/redis"

echo "Creating FreeSWITCH logs directory..."
sudo mkdir -p "$STORAGE_BASE/freeswitch-logs"
sudo chown 1000:1000 "$STORAGE_BASE/freeswitch-logs"  # FreeSWITCH user
sudo chmod 755 "$STORAGE_BASE/freeswitch-logs"

echo "Creating FreeSWITCH recordings directory..."
sudo mkdir -p "$STORAGE_BASE/freeswitch-recordings"
sudo chown 1000:1000 "$STORAGE_BASE/freeswitch-recordings"  # FreeSWITCH user
sudo chmod 755 "$STORAGE_BASE/freeswitch-recordings"

# Set proper SELinux context if SELinux is enabled
if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
    echo "Setting SELinux context for storage directories..."
    sudo setsebool -P container_manage_cgroup on 2>/dev/null || true
    sudo chcon -Rt svirt_sandbox_file_t "$STORAGE_BASE" 2>/dev/null || true
fi

echo "Storage directories created successfully:"
ls -la "$STORAGE_BASE"

echo ""
echo "Directory permissions:"
for dir in mysql redis freeswitch-logs freeswitch-recordings; do
    echo "$(ls -ld "$STORAGE_BASE/$dir")"
done

echo ""
echo "Storage setup completed successfully!"
echo "Total available space:"
df -h "$STORAGE_BASE"