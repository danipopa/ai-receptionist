#!/bin/bash

# Healthcheck script for FreeSWITCH
# This script checks if the FreeSWITCH service is running.

if fs_cli -x "status" | grep -q "OK"; then
  exit 0
else
  exit 1
fi