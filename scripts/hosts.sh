#!/usr/bin/env bash
set -e

HOSTS_FILE="/etc/hosts"

START="# STACKPILOT HOSTS START"
END="# STACKPILOT HOSTS END"

# The exact block we want enforced every time
BLOCK="$START
192.168.56.10 control
192.168.56.11 worker1
192.168.56.12 worker2
$END"

# Must run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "FAIL: run with sudo"
  exit 1
fi

# If an old StackPilot block exists, remove it
if grep -qF "$START" "$HOSTS_FILE"; then
  # delete lines from START to END (inclusive)
  sed -i.bak "/$START/,/$END/d" "$HOSTS_FILE"
fi

# Add the fresh block at the end
printf "\n%s\n" "$BLOCK" >> "$HOSTS_FILE"

# Quick proof
getent hosts control >/dev/null 2>&1 || { echo "FAIL: cannot resolve control"; exit 1; }
getent hosts worker1  >/dev/null 2>&1 || { echo "FAIL: cannot resolve worker1"; exit 1; }
getent hosts worker2  >/dev/null 2>&1 || { echo "FAIL: cannot resolve worker2"; exit 1; }

echo "PASS: StackPilot /etc/hosts block enforced"
