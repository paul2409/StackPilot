#!/usr/bin/env bash
set -e

LOG_FILE="/var/log/stackpilot-provision.log"

sudo touch $LOG_FILE
sudo chmod 666 $LOG_FILE

echo "===== STACKPILOT PROVISION START: $(date) =====" | sudo tee -a $LOG_FILE

echo "Running apt update..." | sudo tee -a $LOG_FILE
sudo apt-get update 
echo "apt update completed" | sudo tee -a $LOG_FILE

echo "Running apt upgrade..." | sudo tee -a $LOG_FILE
sudo apt-get upgrade -y -qq 
echo "apt upgrade completed" | sudo tee -a $LOG_FILE

echo "Installing baseline tools..." | sudo tee -a $LOG_FILE
sudo apt-get install -y -qq curl git jq net-tools ufw ca-certificates unzip dnsutils tcpdump lsof iproute2 shellcheck
echo "baseline tools installed" | sudo tee -a $LOG_FILE

 sudo timedatectl set-timezone Africa/Lagos
 echo "timezone set to Africa/Lagos" | sudo tee -a $LOG_FILE

echo "===== STACKPILOT PROVISION END: $(date) =====" | sudo tee -a $LOG_FILE

