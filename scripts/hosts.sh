#!/usr/bin/env bash
set -e

HOSTS_FILE="/etc/hosts"
MARKER_BEGIN="# STACKPILOT HOSTS BEGIN"
MARKER_END="# STACKPILOT HOSTS END"

# Remove old StackPilot block if it exists (so it's safe to re-run)
sudo sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$HOSTS_FILE"

# Add fresh StackPilot block at the end
sudo bash -c "cat >> $HOSTS_FILE << 'EOF'
$MARKER_BEGIN
192.168.56.10 control
192.168.56.11 worker1
192.168.56.12 worker2
$MARKER_END
EOF"
