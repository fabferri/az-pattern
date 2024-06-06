#!/bin/bash
#
# install Azure CLI in Ubuntu Azure VM. 
# Script verified with Ubuntu 22.04
#
# Get packages needed for the installation process:
sudo apt-get update
sudo apt-get -y install apt-transport-https ca-certificates curl gnupg lsb-release

# Download and install the Microsoft signing key:
sudo mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

# Add the Azure CLI software repository:
AZ_DIST=$(lsb_release -cs)
echo "Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: ${AZ_DIST}
Components: main
Architectures: $(dpkg --print-architecture)
Signed-by: /etc/apt/keyrings/microsoft.gpg" | sudo tee /etc/apt/sources.list.d/azure-cli.sources

# Update repository information and install the azure-cli package:
sudo apt-get update
sudo apt-get  -y install azure-cli