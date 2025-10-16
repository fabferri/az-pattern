# pip install python-dotenv
import os
import sys
import json
from datetime import datetime
from typing import List, Optional, Tuple, Union
from dotenv import load_dotenv, find_dotenv
from azure.identity import DefaultAzureCredential
from azure.mgmt.network import NetworkManagementClient
from azure.core.exceptions import HttpResponseError, ResourceNotFoundError
from azure.mgmt.network.models import VirtualNetworkGateway, GatewayRouteListResult, BgpPeerStatusListResult, VirtualNetworkGatewayConnectionListEntity, VirtualNetworkGatewayConnection

# Load environment variables from .env file
load_dotenv(find_dotenv())

# Configuration
SUBSCRIPTION_ID = os.getenv('AZURE_SUBSCRIPTION_ID')

# Load configuration from config.json
with open("config.json") as f:
    config = json.load(f)
# Load configuration values
RESOURCE_GROUP_NAME = config["RESOURCE_GROUP_NAME"]
VPN_GATEWAY_NAME = config["VPN_GATEWAY_NAME"]

def initialize_azure_client() -> Optional[NetworkManagementClient]:
    """
    Initialize Azure Network Management client with proper authentication.
    
    Returns:
        NetworkManagementClient: Authenticated client or None if initialization fails
    """
    try:
        if not SUBSCRIPTION_ID:
            raise ValueError("AZURE_SUBSCRIPTION_ID environment variable is not set")
        
        credential = DefaultAzureCredential()
        network_client = NetworkManagementClient(credential, SUBSCRIPTION_ID)
        print("Azure Network Management client initialized successfully")
        return network_client
        
    except ValueError as ve:
        print(f"Configuration error: {ve}")
        return None
    except Exception as e:
        print(f"Failed to initialize Azure client: {e}")
        print("Make sure you're authenticated with Azure CLI or have proper credentials configured")
        return None

def get_vpn_gateway_info(network_client: NetworkManagementClient) -> Optional[VirtualNetworkGateway]:
    """
    Retrieve VPN Gateway information.
    
    Args:
        network_client: Azure Network Management client
        
    Returns:
        VirtualNetworkGateway: Gateway object or None if retrieval fails
    """
    try:
        print(f"Retrieving VPN Gateway '{VPN_GATEWAY_NAME}' from resource group '{RESOURCE_GROUP_NAME}'...")
        
        vpn_gateway = network_client.virtual_network_gateways.get(
            RESOURCE_GROUP_NAME, 
            VPN_GATEWAY_NAME
        )
        
        print(f"Found VPN Gateway: {vpn_gateway.name}")
        print(f"  Gateway Type: {vpn_gateway.gateway_type}")
        print(f"  VPN Type: {vpn_gateway.vpn_type}")
        print(f"  BGP Enabled: {vpn_gateway.enable_bgp}")
        print(f"  Location: {vpn_gateway.location}")
        print("-" * 50)
        
        return vpn_gateway
        
    except ResourceNotFoundError:
        print(f"VPN Gateway '{VPN_GATEWAY_NAME}' not found in resource group '{RESOURCE_GROUP_NAME}'")
        print("Please verify the gateway name and resource group are correct")
        return None
    except HttpResponseError as he:
        print(f"HTTP error retrieving VPN Gateway: {he.status_code} - {he.message}")
        return None
    except Exception as e:
        print(f"Unexpected error retrieving VPN Gateway: {e}")
        return None

def get_learned_routes(network_client: NetworkManagementClient) -> Optional[GatewayRouteListResult]:
    """
    Retrieve learned routes from the VPN Gateway.
    
    Args:
        network_client: Azure Network Management client
        
    Returns:
        GatewayRouteListResult: Learned routes or None if retrieval fails
    """
    try:
        print("Fetching learned routes... (this may take a few minutes)")
        
        routing_operation = network_client.virtual_network_gateways.begin_get_learned_routes(
            RESOURCE_GROUP_NAME, 
            VPN_GATEWAY_NAME
        )
        
        routing_table = routing_operation.result()
        print("Learned routes retrieved successfully")
        return routing_table
        
    except HttpResponseError as he:
        print(f"HTTP error retrieving learned routes: {he.status_code} - {he.message}")
        if he.status_code == 400:
            print("This might indicate BGP is not enabled on the gateway")
        return None
    except Exception as e:
        print(f"Error retrieving learned routes: {e}")
        return None

def format_duration(duration_str: str) -> str:
    """
    Format duration string to show only two decimal places for seconds.
    
    Args:
        duration_str: Duration string from Azure API
        
    Returns:
        Formatted duration string with two decimal places for seconds
    """
    if not duration_str or duration_str == 'N/A':
        return "-"
    
    try:
        # Handle various duration formats from Azure API
        # Common formats: "1.23:45:67.123456", "12:34:56.789", "1d 2h 3m 4.567s", etc.
        
        # If it contains 'd', 'h', 'm', 's' - it's in human readable format
        if any(unit in duration_str.lower() for unit in ['d', 'h', 'm', 's']):
            # Look for seconds with decimal places (e.g., "4.567s")
            import re
            seconds_match = re.search(r'(\d+\.?\d*)s', duration_str.lower())
            if seconds_match:
                seconds_part = seconds_match.group(1)
                if '.' in seconds_part:
                    # Format to 2 decimal places
                    formatted_seconds = f"{float(seconds_part):.2f}s"
                    # Replace the original seconds part with formatted one
                    return re.sub(r'\d+\.?\d*s', formatted_seconds, duration_str.lower())
            return duration_str
        
        # If it contains colons, it might be HH:MM:SS.microseconds format
        elif ':' in duration_str:
            parts = duration_str.split(':')
            if len(parts) >= 3 and '.' in parts[-1]:
                # Last part contains seconds with decimal places
                seconds_with_decimal = parts[-1]
                seconds_float = float(seconds_with_decimal)
                parts[-1] = f"{seconds_float:.2f}"
                return ':'.join(parts)
            return duration_str
        
        # If it's just a number with decimals (assuming seconds)
        elif '.' in duration_str and duration_str.replace('.', '').isdigit():
            return f"{float(duration_str):.2f}s"
        
        # Return as-is if we can't parse it
        return duration_str
        
    except (ValueError, AttributeError):
        # If parsing fails, return original
        return duration_str

def print_bgp_peers(unique_peers: dict) -> List[str]:
    """
    Print BGP peers in a formatted table.
    
    Args:
        unique_peers: Dictionary of unique BGP peers with their information
        
    Returns:
        List of connected peer IPs
    """
    print("\nBGP Peer Status")
    print("=" * 120)
    
    if not unique_peers:
        print("No BGP peers found.")
        return []
    
    # Print header
    header = f"{'Peer IP':<15} {'State':<12} {'Status':<12} {'Messages Sent':<15} {'Messages Recv':<15} {'Duration':<15} {'Routes Recv':<12}"
    print(header)
    print("-" * 120)
    
    connected_peers = []
    
    # Print peers
    for peer_ip, peer_info in unique_peers.items():
        state = peer_info['state']
        
        if state == "Connected":
            status_text = "CONNECTED"
            connected_peers.append(peer_ip)
        elif state == "Unknown":
            status_text = "UNKNOWN"
        else:
            status_text = "DISCONNECTED"
        
        messages_sent = str(peer_info['messages_sent']) if peer_info['messages_sent'] > 0 else "0"
        messages_recv = str(peer_info['messages_received']) if peer_info['messages_received'] > 0 else "0"
        duration = format_duration(peer_info['connected_duration'])
        routes_recv = str(peer_info['routes_received']) if peer_info['routes_received'] > 0 else "0"
        
        peer_row = f"{peer_ip:<15} {state:<12} {status_text:<12} {messages_sent:<15} {messages_recv:<15} {duration:<15} {routes_recv:<12}"
        print(peer_row)
    
    print(f"\nTotal BGP peers: {len(unique_peers)}")
    print(f"Connected peers: {len(connected_peers)}")
    
    # Add troubleshooting info for non-connected peers
    disconnected_peers = [ip for ip, info in unique_peers.items() if info['state'] != "Connected"]
    if disconnected_peers:
        print(f"\nNote: {len(disconnected_peers)} peer(s) not connected.")
        print("Troubleshooting tips for disconnected/unknown peers:")
        print("- Verify VPN tunnels are established")
        print("- Check BGP configuration (ASN, IP addresses)")
        print("- Ensure BGP traffic (TCP port 179) is allowed")
        print("- BGP sessions may take time to establish")
    
    return connected_peers

def get_bgp_peers(network_client: NetworkManagementClient) -> Tuple[Optional[BgpPeerStatusListResult], List[str]]:
    """
    Retrieve BGP peer status and return connected peers.
    
    Args:
        network_client: Azure Network Management client
        
    Returns:
        Tuple of (BgpPeerStatusListResult, List of connected peer IPs)
    """
    try:
        print("Fetching BGP peer status...")
        
        bgp_peer_operation = network_client.virtual_network_gateways.begin_get_bgp_peer_status(
            RESOURCE_GROUP_NAME, 
            VPN_GATEWAY_NAME
        )
        
        bgp_peer_status = bgp_peer_operation.result()
        
        if bgp_peer_status.value:
            # Track unique peers to avoid duplicates
            unique_peers = {}
            
            for peer in bgp_peer_status.value:
                peer_ip = peer.neighbor
                peer_state = peer.state
                
                # Store the latest state for each unique peer
                if peer_ip not in unique_peers or peer_state == "Connected":
                    unique_peers[peer_ip] = {
                        'state': peer_state,
                        'messages_sent': getattr(peer, 'messages_sent', 0),
                        'messages_received': getattr(peer, 'messages_received', 0),
                        'connected_duration': getattr(peer, 'connected_duration', 'N/A'),
                        'routes_received': getattr(peer, 'routes_received', 0)
                    }
            
            # Display BGP peers in tabular format
            connected_peers = print_bgp_peers(unique_peers)
            
        else:
            print("\nBGP Peer Status")
            print("=" * 120)
            print("No BGP peers configured")
            connected_peers = []
            
        return bgp_peer_status, connected_peers
        
    except HttpResponseError as he:
        print(f"HTTP error retrieving BGP peer status: {he.status_code} - {he.message}")
        return None, []
    except Exception as e:
        print(f"Error retrieving BGP peer status: {e}")
        return None, []

def get_advertised_routes(network_client: NetworkManagementClient, peer_ip: str) -> Optional[GatewayRouteListResult]:
    """
    Retrieve advertised routes for a specific BGP peer.
    
    Args:
        network_client: Azure Network Management client
        peer_ip: IP address of the BGP peer
        
    Returns:
        GatewayRouteListResult: Advertised routes or None if retrieval fails
    """
    try:
        print(f"Fetching advertised routes for peer {peer_ip}... (this may take a few minutes)")
        
        advertised_operation = network_client.virtual_network_gateways.begin_get_advertised_routes(
            RESOURCE_GROUP_NAME, 
            VPN_GATEWAY_NAME,
            peer=peer_ip
        )
        
        advertised_table = advertised_operation.result()
        print("Advertised routes retrieved successfully")
        return advertised_table
        
    except HttpResponseError as he:
        print(f"HTTP error retrieving advertised routes: {he.status_code} - {he.message}")
        return None
    except Exception as e:
        print(f"Error retrieving advertised routes for peer {peer_ip}: {e}")
        return None

def get_local_network_gateway_ip(network_client: NetworkManagementClient, connection) -> str:
    """
    Get the gateway IP address for a VPN connection by fetching Local Network Gateway details.
    
    Args:
        network_client: Azure Network Management client
        connection: VPN connection object
        
    Returns:
        Gateway IP address or "N/A" if not available
    """
    try:
        if hasattr(connection, 'local_network_gateway2') and connection.local_network_gateway2:
            # Try to get gateway IP directly first
            gateway_ip = getattr(connection.local_network_gateway2, 'gateway_ip_address', None)
            if gateway_ip:
                return gateway_ip
            
            # If not available, fetch the local network gateway details separately
            if hasattr(connection.local_network_gateway2, 'id'):
                lng_id = connection.local_network_gateway2.id
                lng_parts = lng_id.split('/')
                lng_resource_group = lng_parts[4]  # Resource group is at index 4
                lng_name = lng_parts[-1]  # Gateway name is the last part
                
                # Get full local network gateway details
                lng_details = network_client.local_network_gateways.get(lng_resource_group, lng_name)
                return lng_details.gateway_ip_address or "N/A"
                
    except Exception as e:
        print(f"    Warning: Could not fetch local network gateway details: {e}")
    
    return "N/A"

def get_vpn_connections(network_client: NetworkManagementClient) -> Optional[List[Union[VirtualNetworkGatewayConnection, VirtualNetworkGatewayConnectionListEntity]]]:
    """
    Retrieve all VPN connections (site-to-site) associated with the VPN Gateway.
    
    Args:
        network_client: Azure Network Management client
        
    Returns:
        List of VirtualNetworkGatewayConnection objects or None if retrieval fails
    """
    try:
        print("Fetching VPN connections...")
        
        # Get connections directly from the VPN Gateway
        connections = list(network_client.virtual_network_gateways.list_connections(
            RESOURCE_GROUP_NAME,
            VPN_GATEWAY_NAME
        ))
        print(f"Retrieved {len(connections)} connections for VPN Gateway '{VPN_GATEWAY_NAME}'")
        
        if not connections:
            print(f"No VPN connections found for gateway '{VPN_GATEWAY_NAME}'")
            return []
        
        # Get full details for each connection
        detailed_connections = []
        
        for connection in connections:
            try:
                # Get full connection details using the connection name
                full_connection = network_client.virtual_network_gateway_connections.get(
                    RESOURCE_GROUP_NAME,
                    connection.name
                )
                detailed_connections.append(full_connection)
                
            except Exception as detail_error:
                print(f"  Warning: Could not get full details for connection {connection.name}: {detail_error}")
                # Fallback to the list entity if we can't get full details
                detailed_connections.append(connection)
        return detailed_connections
        
    except HttpResponseError as he:
        print(f"HTTP error retrieving VPN connections: {he.status_code} - {he.message}")
        if he.status_code == 403:
            print("Permission denied. Make sure you have 'Network Contributor' or 'Reader' permissions")
        return None
    except Exception as e:
        print(f"Error retrieving VPN connections: {e}")
        print(f"Error type: {type(e).__name__}")
        return None

def print_vpn_connections(network_client: NetworkManagementClient, connections: List[Union[VirtualNetworkGatewayConnection, VirtualNetworkGatewayConnectionListEntity]]) -> None:
    """
    Print VPN connections in a formatted table.
    
    Args:
        network_client: Azure Network Management client
        connections: List of VPN connections to display
    """
    print("\nVPN Gateway Site-to-Site Connections")
    print("=" * 120)
    
    if not connections:
        print("No VPN connections found.")
        return
    
    # Print header
    header = f"{'Connection Name':<25} {'Type':<15} {'Status':<15} {'Remote Gateway IP':<20} {'Provisioning':<15} {'Shared Key':<15}"
    print(header)
    print("-" * 120)
    
    # Track connection statistics
    connected_count = 0
    
    # Print connections
    for connection in connections:
        name = connection.name or "N/A"
        conn_type = connection.connection_type or "N/A"
        status = connection.connection_status or "N/A"
        provisioning = getattr(connection, 'provisioning_state', 'N/A') or "N/A"
        
        # Count connected connections
        if status.lower() == 'connected':
            connected_count += 1
        
        # Get remote gateway info - handle both full and list entity types
        remote_gateway = "N/A"
        
        # Try to get remote gateway information from available properties
        if hasattr(connection, 'local_network_gateway2') and connection.local_network_gateway2:
            # For site-to-site connections - use the helper function to get IP
            remote_gateway = get_local_network_gateway_ip(network_client, connection)
        elif hasattr(connection, 'virtual_network_gateway2') and connection.virtual_network_gateway2:
            # For VNet-to-VNet connections
            remote_gateway = connection.virtual_network_gateway2.name or "VNet Gateway"
        elif hasattr(connection, 'peer') and connection.peer:
            # For ExpressRoute or other peer connections
            if hasattr(connection.peer, 'id'):
                remote_gateway = connection.peer.id.split('/')[-1] or "N/A"
        
        # Determine shared key status
        # Note: Azure API doesn't return actual shared key values for security reasons.
        # We infer the shared key status based on connection state and provisioning status.
        shared_key_set = "Unknown"
        
        if hasattr(connection, 'connection_status') and connection.connection_status:
            # If connection is established, shared key must be properly configured
            if connection.connection_status.lower() == 'connected':
                shared_key_set = "Configured"
            elif connection.connection_status.lower() in ['connecting', 'notconnected']:
                shared_key_set = "Set"
            else:
                shared_key_set = "Unknown"
        elif hasattr(connection, 'provisioning_state') and connection.provisioning_state:
            # If provisioning succeeded, shared key is likely configured
            if connection.provisioning_state.lower() == 'succeeded':
                shared_key_set = "Set"
            else:
                shared_key_set = "Unknown"
        else:
            # For IPsec connections, shared key is mandatory
            if hasattr(connection, 'connection_type') and connection.connection_type == 'IPsec':
                shared_key_set = "Required"
            else:
                shared_key_set = "Unknown"
        
        conn_row = f"{name:<25} {conn_type:<15} {status:<15} {remote_gateway:<20} {provisioning:<15} {shared_key_set:<15}"
        print(conn_row)
    
    print(f"\nTotal connections: {len(connections)}")
    print(f"Connected: {connected_count}, Disconnected: {len(connections) - connected_count}")

def print_routes_table(routes: GatewayRouteListResult, title: str) -> None:
    """
    Print routes in a formatted table.
    
    Args:
        routes: Gateway routes to display
        title: Table title
    """
    print(f"\n{title}")
    print("=" * 140)
    
    if not routes or not routes.value:
        print("No routes found.")
        return
    
    # Print header
    header = f"{'Network':<20} {'Next Hop':<15} {'Local Address':<15} {'Source Peer':<15} {'Origin':<10} {'AS Path':<20} {'Weight':<8}"
    print(header)
    print("-" * 140)
    
    # Print routes
    for route in routes.value:
        network = route.network or "N/A"
        next_hop = route.next_hop or "N/A"
        local_addr = route.local_address or "N/A"
        source_peer = route.source_peer or "N/A"
        origin = route.origin or "N/A"
        as_path = route.as_path or "N/A"
        weight = str(route.weight) if route.weight is not None else "N/A"
        
        route_row = f"{network:<20} {next_hop:<15} {local_addr:<15} {source_peer:<15} {origin:<10} {as_path:<20} {weight:<8}"
        print(route_row)
    
    print(f"\nTotal routes: {len(routes.value)}")

def print_troubleshooting_tips() -> None:
    """Print troubleshooting tips for common issues."""
    print("\nTroubleshooting tips:")
    print("1. Verify the VPN gateway name and resource group are correct")
    print("2. Ensure you have proper permissions to read VPN gateway information")
    print("3. Check if the VPN gateway is a Virtual Network Gateway (not Virtual WAN VPN Gateway)")
    print("4. Make sure BGP is enabled on the gateway to see learned routes")
    print("5. Verify BGP peers are connected to see advertised routes")
    print("6. Check if you're authenticated with Azure CLI: `az login`")

def main() -> None:
    """
    Main function to orchestrate VPN Gateway routing information retrieval.
    """
    # Print datetime header
    current_time = datetime.now()
    datetime_header = current_time.strftime("%d:%m:%y-%H:%M:%S")
    print(f"[{datetime_header}] VPN Gateway Routing Information")
    print("=" * 60)
    
    # Initialize Azure client
    network_client = initialize_azure_client()
    if not network_client:
        print_troubleshooting_tips()
        sys.exit(1)
    
    # Get VPN Gateway information
    vpn_gateway = get_vpn_gateway_info(network_client)
    if not vpn_gateway:
        print_troubleshooting_tips()
        sys.exit(1)
    
    # Get VPN connections
    vpn_connections = get_vpn_connections(network_client)
    if vpn_connections is not None:
        print_vpn_connections(network_client, vpn_connections)
    else:
        print("\nCould not retrieve VPN connections")
    
    # Check if BGP is enabled
    if not vpn_gateway.enable_bgp:
        print("WARNING: BGP is not enabled on this VPN Gateway")
        print("Only static routes will be available, no learned or advertised routes")
        print_troubleshooting_tips()
        return
    
    # Get BGP peers (moved here to show after connections)
    bgp_status, connected_peers = get_bgp_peers(network_client)
    
    # Get learned routes
    learned_routes = get_learned_routes(network_client)
    if learned_routes:
        print_routes_table(learned_routes, "VPN Gateway Learned Routes")
    else:
        print("\nCould not retrieve learned routes")
    
    # Get advertised routes for connected peers
    
    if connected_peers:
        # Get advertised routes for the first connected peer
        peer_ip = connected_peers[0]
        advertised_routes = get_advertised_routes(network_client, peer_ip)
        
        if advertised_routes:
            print_routes_table(advertised_routes, f"VPN Gateway Advertised Routes (to {peer_ip})")
        else:
            print(f"\nCould not retrieve advertised routes for peer {peer_ip}")
    else:
        print("\nNo connected BGP peers found. Cannot retrieve advertised routes.")
        if bgp_status and bgp_status.value:
            print("\nBGP Peer States Explanation:")
            print("- Connected: BGP session is established and routes are being exchanged")
            print("- Unknown: Peer may be initializing, experiencing connectivity issues, or in transition state")
            print("- Disconnected: BGP session is not established")
            print("\nTroubleshooting 'Unknown' state:")
            print("1. Check if VPN tunnels are up and traffic can flow")
            print("2. Verify BGP configuration on both ends (ASN, IP addresses)")
            print("3. Check firewall rules allowing BGP traffic (TCP port 179)")
            print("4. Wait a few minutes as BGP sessions may take time to establish")
    
    # Print summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"VPN Gateway: {VPN_GATEWAY_NAME}")
    print(f"Resource Group: {RESOURCE_GROUP_NAME}")
    
    if vpn_connections is not None:
        total_connections = len(vpn_connections)
        connected_count = sum(1 for conn in vpn_connections 
                            if conn.connection_status and conn.connection_status.lower() == 'connected')
        print(f"Total VPN Connections: {total_connections}")
        print(f"Connected Connections: {connected_count}")
    
    if bgp_status and bgp_status.value:
        total_bgp_peers = len(set(peer.neighbor for peer in bgp_status.value))
        print(f"Total BGP Peers: {total_bgp_peers}")
        print(f"Connected BGP Peers: {len(connected_peers)}")
    else:
        print("BGP Peers: N/A (BGP not enabled or no peers configured)")
    
    print("\nScript completed successfully!")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nScript interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"\nUnexpected error: {e}")
        print_troubleshooting_tips()
        sys.exit(1)