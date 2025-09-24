#!/bin/bash

# Set the FreeSWITCH configuration directory
CONFIG_DIR="/usr/local/freeswitch/conf"

# Copy configuration files to the FreeSWITCH configuration directory
cp -r $CONFIG_DIR/* /usr/local/freeswitch/conf/

# Start FreeSWITCH
exec /usr/local/freeswitch/bin/freeswitch -nonat -c /usr/local/freeswitch/conf/ -loglevel info -u freeswitch -g freeswitch -pidfile /var/run/freeswitch/freeswitch.pid -nf -s 0 -D