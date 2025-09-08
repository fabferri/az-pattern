
# pip install python-dotenv
import os
from dotenv import load_dotenv, find_dotenv

# Load environment variables from .env file
load_dotenv(find_dotenv())

# System call
os.system("")

# Required modules: pip install azure-identity azure-mgmt-resource azure-mgmt-network
#
from datetime import datetime
from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.network.models import (
    VirtualNetwork,
    AddressSpace,
    Subnet,
    PublicIPAddress,
    VirtualNetworkGateway,
    VirtualNetworkGatewayIPConfiguration,
    VirtualNetworkGatewaySku,
    VpnType,
    SubResource
)

# Configuration
subscription_id = os.getenv('AZURE_SUBSCRIPTION_ID')
resource_group_name = "test-python-gw"
location = "uksouth"
vnet2_name = "vnet2"
vnet2_address_prefix = "10.0.2.0/24"
vnet2_subnet1_name = "GatewaySubnet"
vnet2_subnet1_address_prefix = "10.0.2.192/26"
gateway2_name = "gw2"
gw2_pip1_name = f"{gateway2_name}-pip1"
gw2_pip2_name = f"{gateway2_name}-pip2"


# Authenticate
credential = DefaultAzureCredential()
# Use the selected subscription
resource_client = ResourceManagementClient(credential, subscription_id)
network_client = NetworkManagementClient(credential, subscription_id)

print("subscription ID: ", subscription_id, "\n")

# Create Resource Group
resource_client.resource_groups.create_or_update(resource_group_name, {"location": location})

now = datetime.now().strftime("%H:%M:%S")
print(
    f"{now} - Provisioned vnet: {vnet2_name} \
with subnet {vnet2_subnet1_name} and address {vnet2_subnet1_address_prefix}"
)
# Create Virtual Network with GatewaySubnet
vnet_params = VirtualNetwork(
    location=location,
    address_space=AddressSpace(address_prefixes=[vnet2_address_prefix]),
    subnets=[Subnet(name=vnet2_subnet1_name, address_prefix=vnet2_subnet1_address_prefix)]
)
vnet_result = network_client.virtual_networks.begin_create_or_update(
    resource_group_name, vnet2_name, vnet_params
).result()


now = datetime.now().strftime("%H:%M:%S")
print(f"{now} - vnet: {vnet_result.name} provisioned")

# Get GatewaySubnet reference
subnet_info = network_client.subnets.get(resource_group_name, vnet2_name, vnet2_subnet1_name)


now = datetime.now().strftime("%H:%M:%S")
print(f"\n{now} - start Provisioned public IPs for the VPN Gateway: {gateway2_name} \n")

# Create Public IP for VPN Gateway
public_ip_params = PublicIPAddress(
    location=location,
    public_ip_allocation_method="static",
    sku={"name": "Standard"},
    zones=[1, 2, 3],        # Optional: specify zones for high availability
    delete_option="Delete"  # Ensure the IP is deleted with the gateway
)
public_ip1_result = network_client.public_ip_addresses.begin_create_or_update(
    resource_group_name, gw2_pip1_name, public_ip_params
).result()

public_ip2_result = network_client.public_ip_addresses.begin_create_or_update(
    resource_group_name, gw2_pip2_name, public_ip_params
).result()

print(f"{now} - Created public IP: {gw2_pip1_name}")
print(f"{now} - Created public IP: {gw2_pip2_name}")

# Create VPN Gateway
gateway_ip1_config = VirtualNetworkGatewayIPConfiguration(
    name="gwipconfig1",
    subnet=SubResource(id=subnet_info.id),
    public_ip_address=SubResource(id=public_ip1_result.id)
)

gateway_ip2_config = VirtualNetworkGatewayIPConfiguration(
    name="gwipconfig2",
    subnet=SubResource(id=subnet_info.id),
    public_ip_address=SubResource(id=public_ip2_result.id)
)


gateway_params = VirtualNetworkGateway(
    location=location,
    ip_configurations=[gateway_ip1_config, gateway_ip2_config],
    gateway_type="VPN",
    vpn_gateway_generation="Generation2",
    vpn_type="RouteBased",
    enable_bgp=False,
    active=True,
    sku=VirtualNetworkGatewaySku(name="VpnGw2AZ", tier="VpnGw2AZ")
)

now = datetime.now().strftime("%H:%M:%S")
print(f"\n{now} - start Provisioned VPN Gateway: {gateway2_name} \n")

vpn_gateway_result = network_client.virtual_network_gateways.begin_create_or_update(
    resource_group_name, gateway2_name, gateway_params
).result()


print(f"\nVPN Gateway '{vpn_gateway_result.name}' deployed successfully.")
