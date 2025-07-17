#!/bin/bash
# Create directory for Grafana certificates
sudo mkdir -p /opt/grafana-certs

# Copy certificates
sudo cp /etc/letsencrypt/live/pssid-metrics.miserver.it.umich.edu/fullchain.pem /opt/grafana-certs/
sudo cp /etc/letsencrypt/live/pssid-metrics.miserver.it.umich.edu/privkey.pem /opt/grafana-certs/

# Set ownership to UID 472 (Grafana user in container)
sudo chown -R 472:472 /opt/grafana-certs

# Set secure permissions
sudo chmod 400 /opt/grafana-certs/*.pem