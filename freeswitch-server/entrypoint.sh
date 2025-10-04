#!/bin/bash
set -e

echo "Starting FreeSWITCH initialization..."

# Ensure directories exist with proper permissions
echo "Creating directories..."
mkdir -p /var/lib/freeswitch/db
mkdir -p /var/log/freeswitch
mkdir -p /var/run/freeswitch

# Fix ownership (in case volumes are mounted with wrong permissions)
echo "Fixing ownership..."
chown -R freeswitch:freeswitch /var/lib/freeswitch
chown -R freeswitch:freeswitch /var/log/freeswitch
chown -R freeswitch:freeswitch /var/run/freeswitch
chown -R freeswitch:freeswitch /etc/freeswitch

# Ensure the database directory is writable
echo "Setting permissions..."
chmod 755 /var/lib/freeswitch
chmod 755 /var/lib/freeswitch/db

# Test database creation
echo "Testing database creation..."
su freeswitch -c "touch /var/lib/freeswitch/db/test.db && rm -f /var/lib/freeswitch/db/test.db" || {
    echo "ERROR: Cannot create files in database directory!"
    echo "Directory permissions:"
    ls -la /var/lib/freeswitch/
    echo "Process user:"
    id
    echo "Target user:"
    id freeswitch
    exit 1
}

echo "Permissions test passed!"

# Start FreeSWITCH
echo "Starting FreeSWITCH..."
exec /usr/bin/freeswitch -u freeswitch -g freeswitch -nonat -c "$@"