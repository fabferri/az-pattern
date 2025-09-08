# pip install python-dotenv
import os
from dotenv import load_dotenv, find_dotenv

# Load environment variables from .env file
load_dotenv(find_dotenv())

# System call
os.system("")
import sys

# pip install python-dotenv azure-identity azure-mgmt-resource azure-mgmt-network azure-mgmt-compute
from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.compute.models import (
    HardwareProfile,
    NetworkProfile,
    OSProfile,
    StorageProfile,
    VirtualMachine,
    LinuxConfiguration,
    SshConfiguration,
    SshPublicKey,
    ImageReference,
)
from azure.mgmt.network.models import NetworkInterface, NetworkInterfaceIPConfiguration, Subnet, PublicIPAddress
from azure.core.exceptions import ResourceNotFoundError

# Configuration
subscription_id = os.getenv('AZURE_SUBSCRIPTION_ID')
resource_group_name = "test-python-gw"
location = "uksouth"

vnet1_name = "vnet1"
subnet11_name = "subnet11"  # Change to your existing subnet name
subnet11_address_prefix = "10.0.1.0/27"
vnet2_name = "vnet2"
subnet21_name = "subnet21"  # Change to your existing subnet name
subnet21_address_prefix = "10.0.2.0/27"

vm11_name = "vm11"
vm21_name = "vm21"
nic11_name = f"{vm11_name}-nic"
nic21_name = f"{vm21_name}-nic"
public_ip11_name = f"{vm11_name}-pip"
public_ip21_name = f"{vm21_name}-pip"
admin_username = "edge"
admin_ssh_key = os.getenv("ADMIN_SSH_KEY")  # Your SSH public key string

# Authenticate
credential = DefaultAzureCredential()
resource_client = ResourceManagementClient(credential, subscription_id)
network_client = NetworkManagementClient(credential, subscription_id)
compute_client = ComputeManagementClient(credential, subscription_id)


# pip install cryptography
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

#def generate_rsa_keypair_pem(private_key_path="id_rsa.pem", public_key_pem_path="id_rsa_pub.pem", public_key_openssh_path="id_rsa.pub"):
def generate_rsa_keypair(private_key_path="id_rsa.pem",  public_key_openssh_path="id_rsa.pub"):
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa

    # Generate private key
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
    )

    # Write private key in PEM format
    with open(private_key_path, "wb") as f:
        f.write(private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.TraditionalOpenSSL,
            encryption_algorithm=serialization.NoEncryption()
        ))

    # Write public key in OpenSSH format
    public_key = private_key.public_key()
    with open(public_key_openssh_path, "wb") as f:
        f.write(public_key.public_bytes(
            encoding=serialization.Encoding.OpenSSH,
            format=serialization.PublicFormat.OpenSSH
        ))

    print(f"RSA key pair generated: {private_key_path} (private),  {public_key_openssh_path} (OpenSSH public)")



# Check if resource group exists
def ensure_resource_group(resource_client, resource_group_name, location):
    try:
        resource_client.resource_groups.get(resource_group_name)
        print(f"Resource group '{resource_group_name}' already exists. Skipping creation.")
    except ResourceNotFoundError:
        print(f"Resource group '{resource_group_name}' not found. Creating...")
        resource_client.resource_groups.create_or_update(resource_group_name, {"location": location})
        print(f"Resource group '{resource_group_name}' created.")

# Check if resource group exists
def ensure_subnet_exists(resource_group_name, vnet_name, subnet_name, address_prefix):
    try:
        subnet = network_client.subnets.get(resource_group_name, vnet_name, subnet_name)
        print(f"Subnet '{subnet_name}' already exists in vnet '{vnet_name}'. Skipping creation.")
        return subnet
    except ResourceNotFoundError:
        print(f"Subnet '{subnet_name}' not found in vnet '{vnet_name}'. Creating...")
        subnet_params = {
            "address_prefix": address_prefix
        }
        subnet_poller = network_client.subnets.begin_create_or_update(
            resource_group_name,
            vnet_name,
            subnet_name,
            subnet_params
        )
        subnet = subnet_poller.result()
        print(f"Subnet '{subnet_name}' created in vnet '{vnet_name}'.")
        return subnet

# Create VM function
def create_VM(resource_group_name, vm_name, nic_name, public_ip_name, vnet_name, subnet_name, admin_username, admin_ssh_key):
    print(f"Creating VM {vm_name}...")

    try:
        vm = compute_client.virtual_machines.get(resource_group_name, vm_name)
        print(f"VM '{vm_name}' already exists. Skipping creation.")
        return vm
    except ResourceNotFoundError:
        print(f"VM '{vm_name}' not found. Creating...")

    # Get existing subnet
    subnet = network_client.subnets.get(resource_group_name, vnet_name, subnet_name)

    # Ensure Public IP exists
    try:
        public_ip = network_client.public_ip_addresses.get(resource_group_name, public_ip_name)
        print(f"Public IP '{public_ip_name}' already exists. Skipping creation.")
    except ResourceNotFoundError:
        print(f"Public IP '{public_ip_name}' not found. Creating...")
        public_ip_params = PublicIPAddress(
            location=location,
            public_ip_allocation_method="static",
            sku={"name": "Standard"},
            zones=[1, 2, 3],
            delete_option="Delete"
        )
        public_ip = network_client.public_ip_addresses.begin_create_or_update(
            resource_group_name, public_ip_name, public_ip_params
        ).result()

    # Ensure NIC exists
    try:
        nic = network_client.network_interfaces.get(resource_group_name, nic_name)
        print(f"NIC '{nic_name}' already exists. Skipping creation.")
    except ResourceNotFoundError:
        print(f"NIC '{nic_name}' not found. Creating...")
        nic_params = {
            "location": location,
            "ip_configurations": [{
                "name": f"{nic_name}-ipconfig",
                "subnet": {"id": subnet.id},
                "public_ip_address": {"id": public_ip.id}
            }]
        }
        nic = network_client.network_interfaces.begin_create_or_update(
            resource_group_name, nic_name, nic_params
        ).result()
        print(f"\nNIC {nic_name} created with ID: {nic.id}")
    
    # VM parameters
    vm_params = {
        "location": location,
        "hardware_profile": {"vm_size": "Standard_B1s"},
        "storage_profile": {
            "image_reference": {
                "publisher": "canonical",
                "offer": "ubuntu-24_04-lts",
                "sku": "server",
                "version": "latest"
            },
            "os_disk": {
                "name": f"{vm_name}-osdisk",
                "create_option": "FromImage"
            }
        },
        "os_profile": {
            "computer_name": vm_name,
            "admin_username": admin_username,
            "linux_configuration": {
                "disable_password_authentication": True,
                "ssh": {
                    "public_keys": [{
                        "path": f"/home/{admin_username}/.ssh/authorized_keys",
                        "key_data": admin_ssh_key
                    }]
                }
            }
        },
        "network_profile": {
            "network_interfaces": [{
                "id": nic.id,
                "primary": True
            }]
        }
    }
    print(f"Creating VM {vm_name}...")
    vm_poller = compute_client.virtual_machines.begin_create_or_update(
        resource_group_name, vm_name, vm_params
    )
    vm_result = vm_poller.result()
    print(f"VM {vm_name} created with ID: {vm_result.id}")


if not (os.path.exists("id_rsa.pem") and os.path.exists("id_rsa.pub")):
    # Generate RSA key pair if not provided
    generate_rsa_keypair()
    print("RSA key pair generated.")
else:
    print("RSA key pair already exists. Skipping generation.")

# Read OpenSSH public key for the VMs
with open("id_rsa.pub", "r") as f:
    admin_ssh_key = f.read().strip()
print(admin_ssh_key)

ensure_resource_group(resource_client, resource_group_name, location)
ensure_subnet_exists(resource_group_name, vnet1_name, subnet11_name, subnet11_address_prefix)
ensure_subnet_exists(resource_group_name, vnet2_name, subnet21_name, subnet21_address_prefix)



# Call the function to create the VM
create_VM(resource_group_name, vm11_name, nic11_name, public_ip11_name, vnet1_name, subnet11_name, admin_username, admin_ssh_key)
create_VM(resource_group_name, vm21_name, nic21_name, public_ip21_name, vnet2_name, subnet21_name, admin_username, admin_ssh_key)

sys.exit("end program")

