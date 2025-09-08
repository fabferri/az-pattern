# pip install python-dotenv
import os
from dotenv import load_dotenv, find_dotenv

# Load environment variables from .env file
load_dotenv(find_dotenv())

# System call
os.system("")

from azure.identity import DefaultAzureCredential
from azure.mgmt.network import NetworkManagementClient

# Configuration
subscription_id = os.getenv('AZURE_SUBSCRIPTION_ID')
resource_group_name = "test-python-gw"
gateway_name = "gw1"

# Authenticate
credential = DefaultAzureCredential()
network_client = NetworkManagementClient(credential, subscription_id)

# Get the VPN Gateway
vpn_gateway = network_client.virtual_network_gateways.get(resource_group_name, gateway_name)

# Extract the public IP configuration
for ip_config in vpn_gateway.ip_configurations:
    public_ip_id = ip_config.public_ip_address.id
    public_ip_name = public_ip_id.split('/')[-1]
    public_ip = network_client.public_ip_addresses.get(resource_group_name, public_ip_name)
    print(f"Public IP Address: {public_ip.ip_address}")
