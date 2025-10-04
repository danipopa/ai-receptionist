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
chmod 775 /var/lib/freeswitch/db  # Make db directory writable

# Test database creation
echo "Testing database creation..."
echo "Current user: $(id)"
echo "Trying to create test file as root..."
touch /var/lib/freeswitch/db/test-root.db && echo "✓ Root can write" || echo "✗ Root cannot write"

echo "Trying to create test file as freeswitch user..."
su freeswitch -c "touch /var/lib/freeswitch/db/test-freeswitch.db" && echo "✓ freeswitch can write" || echo "✗ freeswitch cannot write"

# Check what's in the db directory
echo "Contents of db directory:"
ls -la /var/lib/freeswitch/db/

# Clean up test files
rm -f /var/lib/freeswitch/db/test-*.db

echo "Permissions test passed!"

# Start FreeSWITCH
echo "Starting FreeSWITCH..."
exec /usr/bin/freeswitch -u freeswitch -g freeswitch -nonat -c "$@"