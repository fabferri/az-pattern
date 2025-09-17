import os
import sys
import logging
import traceback

from datetime import datetime

# pip install cryptography
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

# pip install azure-identity azure-mgmt-resource azure-mgmt-network azure-mgmt-compute
from azure.identity import DefaultAzureCredential
from azure.core.exceptions import ResourceNotFoundError
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.compute.models import (
    HardwareProfile, StorageProfile, OSProfile, NetworkProfile,
    NetworkInterfaceReference, LinuxConfiguration, SshConfiguration,
    SshPublicKey, VirtualMachineExtension
)
# pip install python-dotenv
from dotenv import load_dotenv, find_dotenv

# -------------------- Logging Setup --------------------
# %(asctime)s -> the timestamp of the log event
# %(levelname)s -> the log level (INFO, ERROR, etc.)
# %(message)s -> the actual log message
logging.basicConfig(
    level=logging.ERROR,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[logging.StreamHandler(sys.stdout)]

)

# Load environment variables from .env file
load_dotenv(find_dotenv())

# -------------------- RSA Key Generation --------------------
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
    now = datetime.now().strftime("%H:%M:%S")
    print(f"{now} - RSA key pair generated: {private_key_path} (private),  {public_key_openssh_path} (OpenSSH public)")

# -------------------- Authentication --------------------
def get_clients(subscription_id):
    credential = DefaultAzureCredential()
    return {
        "resource": ResourceManagementClient(credential, subscription_id),
        "network": NetworkManagementClient(credential, subscription_id),
        "compute": ComputeManagementClient(credential, subscription_id)
    }

# -------------------- Modular Functions --------------------
def ensure_resource_group(resource_client, resource_group_name, location):
    try:
        resource_client.resource_groups.get(resource_group_name)
        logging.info(f"Resource group '{resource_group_name}' already exists.")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - Resource group '{resource_group_name}' already exists.")
    except ResourceNotFoundError:
        logging.info(f"Creating resource group '{resource_group_name}'...")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - Creating resource group '{resource_group_name}'...")
        resource_client.resource_groups.create_or_update(resource_group_name, {"location": location})

def ensure_vnet(network_client, resource_group_name, vnet_name, location):
    try:
        network_client.virtual_networks.get(resource_group_name, vnet_name)
        logging.info(f"VNet '{vnet_name}' already exists.")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - VNet '{vnet_name}' already exists.")
    except ResourceNotFoundError:
        logging.info(f"Creating VNet '{vnet_name}'...")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - Creating VNet '{vnet_name}'...")
        network_client.virtual_networks.begin_create_or_update(
            resource_group_name,
            vnet_name,
            {
                "location": location,
                "address_space": {"address_prefixes": ["10.0.0.0/24"]}
            }
        ).result()

def ensure_subnet(network_client, resource_group_name, vnet_name, subnet_name):
    try:
        network_client.subnets.get(resource_group_name, vnet_name, subnet_name)
        logging.info(f"Subnet '{subnet_name}' already exists.")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - Subnet '{subnet_name}' already exists.")
    except ResourceNotFoundError:
        logging.info(f"Creating Subnet '{subnet_name}'...")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - Creating Subnet '{subnet_name}'...")
        network_client.subnets.begin_create_or_update(
            resource_group_name,
            vnet_name,
            subnet_name,
            {"address_prefix": "10.0.0.0/27"}
        ).result()

# Ensure NSG exists
def ensure_nsg(network_client, resource_group_name, nsg_name, location):
    try:
        network_client.network_security_groups.get(resource_group_name, nsg_name)
        logging.info(f"NSG '{nsg_name}' already exists.")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - NSG '{nsg_name}' already exists.")
    except ResourceNotFoundError:
        logging.info(f"Creating NSG '{nsg_name}'...")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - Creating NSG '{nsg_name}'...")
        network_client.network_security_groups.begin_create_or_update(
            resource_group_name,
            nsg_name,
            {
                "location": location,
                "security_rules": [
                    {
                        "name": "AllowSSH",
                        "protocol": "Tcp",
                        "source_port_range": "*",
                        "destination_port_range": "22",
                        "source_address_prefix": "*",
                        "destination_address_prefix": "*",
                        "access": "Allow",
                        "priority": 600,
                        "direction": "Inbound"
                    },
                    {
                        "name": "AllowHTTP",
                        "protocol": "Tcp",
                        "source_port_range": "*",
                        "destination_port_range": "80",
                        "source_address_prefix": "*",
                        "destination_address_prefix": "*",
                        "access": "Allow",
                        "priority": 700,
                        "direction": "Inbound"
                    }
                ]
            }
        ).result()

def ensure_public_ip(network_client, resource_group_name, ip_name, location):
    try:
        network_client.public_ip_addresses.get(resource_group_name, ip_name)
        logging.info(f"Public IP '{ip_name}' already exists.")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - Public IP '{ip_name}' already exists.")
    except ResourceNotFoundError:
        logging.info(f"Creating Public IP '{ip_name}'...")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - Creating Public IP '{ip_name}'...")
        network_client.public_ip_addresses.begin_create_or_update(
            resource_group_name,
            ip_name,
            {
                "location": location,
                "sku": {"name": "Standard"},
                "zones": [1, 2, 3],
                "public_ip_allocation_method": "Static",
                "delete_option": "Delete"
            }
        ).result()

def ensure_nic(network_client, resource_group_name, nic_name, location, vnet_name, subnet_name, ip_name):
    try:
        nic = network_client.network_interfaces.get(resource_group_name, nic_name)
        logging.info(f"NIC '{nic_name}' already exists.")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - NIC '{nic_name}' already exists.")
        return nic
    except ResourceNotFoundError:
        # create NSG for the NIC
        nsg_name = f"{nic_name}-nsg"
        
        ensure_nsg(network_client, resource_group_name, nsg_name, location)
        nsg = network_client.network_security_groups.get(resource_group_name, nsg_name)

        logging.info(f"Creating NIC '{nic_name}'...")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - Creating NIC '{nic_name}'...")

        subnet_info = network_client.subnets.get(resource_group_name, vnet_name, subnet_name)
        ip_info = network_client.public_ip_addresses.get(resource_group_name, ip_name)


        nic = network_client.network_interfaces.begin_create_or_update(
            resource_group_name,
            nic_name,
            {
                "location": location,
                "ip_configurations": [{
                    "name": "ifconfig1",
                    "subnet": {"id": subnet_info.id},
                    "public_ip_address": {"id": ip_info.id, "delete_option": "Delete"}
                }],
                "network_security_group": {"id": nsg.id}
            }
        ).result()
        return nic

def ensure_vm(compute_client, resource_group_name, vm_name, location, vm_size, image_reference, admin_username, admin_ssh_key, nic_id):
    try:
        compute_client.virtual_machines.get(resource_group_name, vm_name)
        logging.info(f"VM '{vm_name}' already exists.")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - VM '{vm_name}' already exists.")
    except ResourceNotFoundError:
        logging.info(f"Creating VM '{vm_name}'...")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - Creating VM '{vm_name}'...")

        vm_parameters = {
            "location": location,
            "hardware_profile": HardwareProfile(vm_size=vm_size),
            "storage_profile": StorageProfile(
                image_reference=image_reference,
                os_disk={
                    "name": f"{vm_name}-osdisk",
                    "caching": "ReadWrite",
                    "create_option": "FromImage"
                }
            ),
            "os_profile": OSProfile(
                computer_name=vm_name,
                admin_username=admin_username,
                linux_configuration=LinuxConfiguration(
                    disable_password_authentication=True,
                    ssh=SshConfiguration(
                        public_keys=[SshPublicKey(
                            path=f"/home/{admin_username}/.ssh/authorized_keys",
                            key_data=admin_ssh_key
                        )]
                    )
                )
            ),
            "network_profile": NetworkProfile(
                network_interfaces=[NetworkInterfaceReference(id=nic_id)]
            )
        }

        compute_client.virtual_machines.begin_create_or_update(
            resource_group_name,
            vm_name,
            vm_parameters
        ).result()

def ensure_custom_script_extension(compute_client, resource_group_name, vm_name, location, extension_name, settings):
    try:
        compute_client.virtual_machine_extensions.get(resource_group_name, vm_name, extension_name)
        logging.info(f"Custom Script Extension '{extension_name}' already exists.")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - Custom Script Extension '{extension_name}' already exists.")
    except ResourceNotFoundError:
        logging.info(f"Adding Custom Script Extension '{extension_name}'...")
        now = datetime.now().strftime("%H:%M:%S")
        print(f"{now} - Adding Custom Script Extension '{extension_name}'...")

        extension_params = VirtualMachineExtension(
            location=location,
            publisher="Microsoft.Azure.Extensions",
            type_properties_type="CustomScript",
            type_handler_version="2.1",
            auto_upgrade_minor_version=True,
            settings=settings
        )
        compute_client.virtual_machine_extensions.begin_create_or_update(
            resource_group_name,
            vm_name,
            extension_name,
            extension_params
        ).result()
    # ...existing code...
# -------------------- Execution --------------------
def main():
    try:
        # Parameters
        subscription_id = os.getenv("AZURE_SUBSCRIPTION_ID")
        admin_username = os.getenv("ADMINISTRATOR_USERNAME")  
        location = "uksouth"
        resource_group_name = "test-rg-linux"
        vnet_name = "vnet1"
        subnet_name = "subnet1"
        vm_name = "vm1"
        ip_name = f"{vm_name}-pip"
        nic_name = f"{vm_name}-nic"
        vm_size = "Standard_B1s"      
        image_reference = {
            "publisher": "Canonical",
            "offer": "ubuntu-24_04-lts",
            "sku": "server",
            "version": "latest"
        }
        custom_script_settings = {
            "commandToExecute": "#!/bin/bash\nsudo apt-get update -y\nsudo apt-get install nginx -y\nsudo systemctl enable nginx\nsudo systemctl start nginx\necho '<h1>Deployed via Azure Custom Script Extension</h1>' | sudo tee /var/www/html/index.nginx-debian.html"
        }

        if not (os.path.exists("id_rsa.pem") and os.path.exists("id_rsa.pub")):
        # Generate RSA key pair if not provided
            generate_rsa_keypair()
            now = datetime.now().strftime("%H:%M:%S")
            print(f"{now} - RSA key pair generated.")
        else:
            now = datetime.now().strftime("%H:%M:%S")
            print(f"{now} - RSA key pair already exists. Skipping generation.")

        # Read OpenSSH public key for the VMs
        with open("id_rsa.pub", "r") as f:
            admin_ssh_key = f.read().strip()
            now = datetime.now().strftime("%H:%M:%S")
            print(f"{now} - Read OpenSSH public key:")
            print(admin_ssh_key)

        clients = get_clients(subscription_id)

        ensure_resource_group(clients["resource"], resource_group_name, location)
        ensure_vnet(clients["network"], resource_group_name, vnet_name, location)
        ensure_subnet(clients["network"], resource_group_name, vnet_name, subnet_name)
        ensure_public_ip(clients["network"], resource_group_name, ip_name, location)
        nic = ensure_nic(clients["network"], resource_group_name, nic_name, location, vnet_name, subnet_name, ip_name)
        ensure_vm(clients["compute"], resource_group_name, vm_name, location, vm_size, image_reference, admin_username, admin_ssh_key, nic.id)
        ensure_custom_script_extension(
            compute_client=clients["compute"],
            resource_group_name=resource_group_name,
            vm_name=vm_name,
            location=location,
            extension_name="CustomScriptExtension",
            settings=custom_script_settings
        )

        logging.info("VM deployment complete with Custom Script Extension.")
    except Exception as e:
        logging.error("Deployment failed:")
        traceback.print_exc()

if __name__ == "__main__":
    main()
