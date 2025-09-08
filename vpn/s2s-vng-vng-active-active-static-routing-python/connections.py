# pip install python-dotenv
import datetime
import os
from dotenv import load_dotenv, find_dotenv

import sys

# Load environment variables from .env file
load_dotenv(find_dotenv())

# System call
os.system("")

from azure.identity import DefaultAzureCredential
from azure.mgmt.network import NetworkManagementClient
from azure.core.exceptions import ResourceNotFoundError, HttpResponseError



# Configuration
subscription_id = os.getenv('AZURE_SUBSCRIPTION_ID')
shared_service_key = os.getenv('SHARED_SERVICE_KEY')
resource_group_name = "test-python-gw"
gateway1_name = "gw1"
gateway2_name = "gw2"
location = "uksouth"
vnet1_address_prefix = "10.0.1.0/24"
vnet2_address_prefix = "10.0.2.0/24"

local_gateway11_name = "localNetGw11"
local_gateway12_name = "localNetGw12"
local_gateway21_name = "localNetGw21"
local_gateway22_name = "localNetGw22"

vpn_connection11_name = "conn11"
vpn_connection12_name = "conn12"
vpn_connection21_name = "conn21"
vpn_connection22_name = "conn22"

# Authenticate
credential = DefaultAzureCredential()
network_client = NetworkManagementClient(credential, subscription_id)

def ensure_vpn_gateway_exists(resource_group_name, gateway_name):
    try:
        vpn_gateway = network_client.virtual_network_gateways.get(resource_group_name, gateway_name)
        print(f"VPN Gateway '{gateway_name}' found.")
        return None
    except ResourceNotFoundError:
        sys.exit(f"VPN Gateway '{gateway_name}' not found.")
        return None

ensure_vpn_gateway_exists(resource_group_name, gateway1_name)
ensure_vpn_gateway_exists(resource_group_name, gateway2_name)

# Get the VPN Gateway
vpn_gateway1 = network_client.virtual_network_gateways.get(resource_group_name, gateway1_name)
temp_gw1pubIP1=network_client.public_ip_addresses.get(resource_group_name, vpn_gateway1.ip_configurations[0].public_ip_address.id.split('/')[-1])
temp_gw1pubIP2=network_client.public_ip_addresses.get(resource_group_name, vpn_gateway1.ip_configurations[1].public_ip_address.id.split('/')[-1])

gw1pubIP1=temp_gw1pubIP1.ip_address
gw1pubIP2=temp_gw1pubIP2.ip_address

print(f"gateway: {gateway1_name} ,  Public IP Address: {gw1pubIP1}")
print(f"gateway: {gateway1_name} ,  Public IP Address: {gw1pubIP2}")


vpn_gateway2 = network_client.virtual_network_gateways.get(resource_group_name, gateway2_name)
temp_gw2pubIP1=network_client.public_ip_addresses.get(resource_group_name, vpn_gateway2.ip_configurations[0].public_ip_address.id.split('/')[-1])
temp_gw2pubIP2=network_client.public_ip_addresses.get(resource_group_name, vpn_gateway2.ip_configurations[1].public_ip_address.id.split('/')[-1])

gw2pubIP1=temp_gw2pubIP1.ip_address
gw2pubIP2=temp_gw2pubIP2.ip_address

print(f"gateway: {gateway2_name} ,  Public IP Address: {gw2pubIP1}")
print(f"gateway: {gateway2_name} ,  Public IP Address: {gw2pubIP2}")



################################################################################
# function to create Local Network Gateway
def CreateLocalNetworkGateway(location, resource_group_name, local_gateway_name, gwPubIP, remote_address_prefix):
    try:
        now = datetime.datetime.now().strftime("%H:%M:%S")
        # Try to get the local network gateway
        network_client.local_network_gateways.get(resource_group_name, local_gateway_name)
        print(f"{now} - Local Network Gateway {local_gateway_name} already exists. Skipping creation.")
        return
    except ResourceNotFoundError:
        print(f"{now} -Local Network Gateway {local_gateway_name} not found. Creating...")

    local_gateway_params = {
        "location": location,
        "gateway_ip_address": gwPubIP,
        "local_network_address_space": {
            "address_prefixes": [remote_address_prefix]
        }
    }
    local_gateway_poller = network_client.local_network_gateways.begin_create_or_update(
       resource_group_name=resource_group_name,
       local_network_gateway_name=local_gateway_name,
       parameters=local_gateway_params
    )
    local_gateway_result = local_gateway_poller.result()
    print(f"Local Network Gateway {local_gateway_name} created.")
    print(f"Local Network Gateway {local_gateway_name} results: {local_gateway_result.provisioning_state}")



def CreateConnection(location, resource_group_name, connection_name, virtual_network_gateway_name, local_network_gateway_name, shared_key):
    try:
        now = datetime.datetime.now().strftime("%H:%M:%S")
        # Check if the VPN connection already exists
        network_client.virtual_network_gateway_connections.get(resource_group_name, connection_name)
        print(f"{now} - VPN Connection {connection_name} already exists. Skipping creation.")
        return
    except (ResourceNotFoundError, HttpResponseError):
        print(f"{now} - VPN Connection {connection_name} not found. {ResourceNotFoundError} )")
        print(f"{now} - Creating VPN Connection {connection_name}...")

        print(f"{now} ----------------------------------------------------------------")

        now = datetime.datetime.now().strftime("%H:%M:%S")
        print(f"{now} - VPN Connection {connection_name} already exists. Skipping creation.")
        local_gateway_result = network_client.local_network_gateways.get(
                resource_group_name, local_network_gateway_name  # or the correct gateway name you want
            )
        print(f"{now} - Local Network Gateway {local_network_gateway_name} found with ID: {local_gateway_result.id}")
        
        vpn_connection_params = {
            "location": location,
            "connection_type": "IPsec",
            "connection_protocol": "IKEv2", 
            "virtual_network_gateway1": {
                "id": f"/subscriptions/{subscription_id}/resourceGroups/{resource_group_name}/providers/Microsoft.Network/virtualNetworkGateways/{virtual_network_gateway_name}"
            },
            "local_network_gateway2": {
                "id": local_gateway_result.id
            },
            "shared_key": shared_key,  # Must match on both sides
            "enable_bgp": False
        }

        print(f"Creating VPN Connection {connection_name}...")
        vpn_connection_poller = network_client.virtual_network_gateway_connections.begin_create_or_update(
            resource_group_name=resource_group_name,
            virtual_network_gateway_connection_name=connection_name,
            parameters=vpn_connection_params
        )

        try:
           vpn_connection_result = vpn_connection_poller.result()
           now = datetime.datetime.now().strftime("%H:%M:%S")
           print(f"{now} - VPN Connection {connection_name} created.")
           print(f"{now} - vpn connection {connection_name} results: {vpn_connection_result}")
        except Exception as e:
           print(f"Error creating VPN Connection {connection_name}: {e}")

CreateLocalNetworkGateway(location, resource_group_name, local_gateway11_name, gw1pubIP1, vnet1_address_prefix)
CreateLocalNetworkGateway(location, resource_group_name, local_gateway12_name, gw1pubIP2, vnet1_address_prefix)
CreateLocalNetworkGateway(location, resource_group_name, local_gateway21_name, gw2pubIP1, vnet2_address_prefix)
CreateLocalNetworkGateway(location, resource_group_name, local_gateway22_name, gw2pubIP2, vnet2_address_prefix)

CreateConnection(location, resource_group_name, vpn_connection11_name, gateway1_name, local_gateway21_name, shared_service_key)
CreateConnection(location, resource_group_name, vpn_connection12_name, gateway1_name, local_gateway22_name, shared_service_key)
CreateConnection(location, resource_group_name, vpn_connection21_name, gateway2_name, local_gateway11_name, shared_service_key)
CreateConnection(location, resource_group_name, vpn_connection22_name, gateway2_name, local_gateway12_name, shared_service_key)


sys.exit("end program")

