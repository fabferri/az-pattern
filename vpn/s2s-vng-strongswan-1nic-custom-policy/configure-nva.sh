#!/bin/bash
#
# configure-nva.sh
#
# Configures an Ubuntu 24.04 NVA as a strongSwan IPsec gateway with route-based
# VPN using XFRM interfaces, BGP via FRR, and reboot-persistent configuration.
#
# Usage:
#   1. Deploy Azure infra with 01_azvpn.ps1 and 02_vpnconnections.ps1
#   2. Fill in the variables below from deployment outputs
#   3. SSH to the NVA management IP and run: sudo bash configure-nva.sh
#
# All configuration is reboot-persistent.
#

set -euo pipefail

###############################################################################
# Variables — fill these from ARM template deployment outputs
###############################################################################

# NVA network settings (single NIC: management + IPsec on eth0)
NVA_PRIVATE_IP="10.2.0.10"                  # NVA single NIC private IP
NVA_PUBLIC_IP="YOURVALUE"                   # NVA single NIC public IP (Azure-assigned)
NVA_IFACE="eth0"                            # NVA interface name (single NIC)
NVA_GW="10.2.0.1"                           # Default gateway for the NVA subnet

# NVA BGP settings
NVA_BGP_ASN=65020                           # NVA BGP ASN (must match localNetworkGateway)
NVA_BGP_IP0="192.168.0.1"                   # BGP source IP on ipsec0
NVA_BGP_IP1="192.168.0.2"                   # BGP source IP on ipsec1

# Azure VPN Gateway settings (from 01_azvpn.ps1 deployment output)
VPNGW_PIP0="YOURVALUE"                      # VPN GW instance 0 public IP
VPNGW_PIP1="YOURVALUE"                      # VPN GW instance 1 public IP
VPNGW_BGP_IP0="10.1.0.5"                    # VPN GW instance 0 BGP IP
VPNGW_BGP_IP1="10.1.0.4"                    # VPN GW instance 1 BGP IP
VPNGW_BGP_ASN=65010                         # VPN GW BGP ASN

# IPsec pre-shared key (from 02_vpnconnections deployment output: sharedSecret_conn1)
VPN_PSK="YOURVALUE"

# XFRM interface IDs (must match swanctl.conf if_id_in / if_id_out)
XFRM_IF_ID0=41
XFRM_IF_ID1=42

# Network to advertise via BGP to Azure
ADVERTISE_NETWORK="10.2.0.0/24"

# Additional local subnets (reachable via NVA subnet gateway)
SUBNET_APP="10.2.0.64/27"                   # subnetApp — reachable via NVA gateway

###############################################################################
# 1. Install packages
###############################################################################
echo "=== [1/7] Installing packages ==="
apt-get update -qq
apt-get install -y strongswan strongswan-swanctl frr net-tools

###############################################################################
# 2. Persistent sysctl — /etc/sysctl.d/60-vpn.conf
###############################################################################
echo "=== [2/7] Configuring sysctl (persistent) ==="
cat > /etc/sysctl.d/60-vpn.conf << 'SYSCTL_EOF'
# IP forwarding for transit traffic
net.ipv4.ip_forward = 1
# Disable ICMP redirects (required for IPsec)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
# Disable reverse-path filtering for XFRM interfaces
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
SYSCTL_EOF

sysctl --system > /dev/null 2>&1
echo "  ip_forward = $(sysctl -n net.ipv4.ip_forward)"

###############################################################################
# 3. strongSwan charon — disable automatic route installation
###############################################################################
echo "=== [3/7] Configuring strongSwan charon ==="
# We manage routes manually via the XFRM systemd service
if grep -q '# install_routes = yes' /etc/strongswan.d/charon.conf 2>/dev/null; then
    sed -i 's/# install_routes = yes/install_routes = no/' /etc/strongswan.d/charon.conf
elif grep -q 'install_routes = yes' /etc/strongswan.d/charon.conf 2>/dev/null; then
    sed -i 's/install_routes = yes/install_routes = no/' /etc/strongswan.d/charon.conf
else
    # If the setting doesn't exist, append it
    echo "charon { install_routes = no }" >> /etc/strongswan.d/charon.conf
fi
echo "  install_routes = no"

###############################################################################
# 4. swanctl.conf — IPsec tunnel configuration (persistent)
###############################################################################
echo "=== [4/7] Writing /etc/swanctl/swanctl.conf ==="
cat > /etc/swanctl/swanctl.conf << SWAN_EOF
connections {
   gw0 {
        local_addrs  = ${NVA_PRIVATE_IP}
        remote_addrs = ${VPNGW_PIP0}
        version = 2
        proposals = aes256gcm16-prfsha256-modp2048
        keyingtries = 0
        encap = yes
        mobike = no
        reauth_time = 28800
        local {
            auth = psk
            id = ${NVA_PUBLIC_IP}
        }
        remote {
            auth = psk
            id = ${VPNGW_PIP0}
            revocation = relaxed
        }
        children {
            s2s0 {
                local_ts = 0.0.0.0/0
                remote_ts = 0.0.0.0/0
                esp_proposals = aes256gcm16-modp2048
                dpd_action = restart
                close_action = restart
                start_action = start
                rekey_time = 3600
            }
        }
        if_id_in = ${XFRM_IF_ID0}
        if_id_out = ${XFRM_IF_ID0}
   }
   gw1 {
        local_addrs  = ${NVA_PRIVATE_IP}
        remote_addrs = ${VPNGW_PIP1}
        version = 2
        proposals = aes256gcm16-prfsha256-modp2048
        keyingtries = 0
        encap = yes
        mobike = no
        reauth_time = 28800
        local {
            auth = psk
            id = ${NVA_PUBLIC_IP}
        }
        remote {
            auth = psk
            id = ${VPNGW_PIP1}
            revocation = relaxed
        }
        children {
            s2s1 {
                local_ts = 0.0.0.0/0
                remote_ts = 0.0.0.0/0
                esp_proposals = aes256gcm16-modp2048
                dpd_action = restart
                close_action = restart
                start_action = start
                rekey_time = 3600
            }
        }
        if_id_in = ${XFRM_IF_ID1}
        if_id_out = ${XFRM_IF_ID1}
   }
}
secrets {
   ike-gw0 {
        id-0 = ${VPNGW_PIP0}
        secret = "${VPN_PSK}"
   }
   ike-gw1 {
        id-0 = ${VPNGW_PIP1}
        secret = "${VPN_PSK}"
   }
}
SWAN_EOF

###############################################################################
# 5. XFRM interfaces + routes — systemd service (persistent)
###############################################################################
echo "=== [5/7] Creating XFRM systemd service ==="

# --- Setup script ---
cat > /usr/local/bin/vpn-xfrm-setup.sh << SETUP_EOF
#!/bin/bash
set -e

# Create XFRM interface for tunnel 0
ip link add ipsec0 type xfrm dev ${NVA_IFACE} if_id ${XFRM_IF_ID0}
ip addr add ${NVA_BGP_IP0}/32 dev ipsec0
ip link set ipsec0 up

# Create XFRM interface for tunnel 1
ip link add ipsec1 type xfrm dev ${NVA_IFACE} if_id ${XFRM_IF_ID1}
ip addr add ${NVA_BGP_IP1}/32 dev ipsec1
ip link set ipsec1 up

# Routes to VPN Gateway BGP peers through XFRM tunnels
ip route add ${VPNGW_BGP_IP0}/32 dev ipsec0
ip route add ${VPNGW_BGP_IP1}/32 dev ipsec1

# Routes to VPN Gateway public IPs via NVA gateway
ip route add ${VPNGW_PIP0}/32 via ${NVA_GW}
ip route add ${VPNGW_PIP1}/32 via ${NVA_GW}

# Throw routes in table 220 to prevent strongSwan routing loops
ip route add throw ${VPNGW_PIP0}/32 table 220
ip route add throw ${VPNGW_PIP1}/32 table 220

# Route to subnetApp via NVA gateway (more specific than /24 blackhole)
ip route add ${SUBNET_APP} via ${NVA_GW}

echo "XFRM interfaces and routes configured"
SETUP_EOF

# --- Teardown script ---
cat > /usr/local/bin/vpn-xfrm-teardown.sh << TEARDOWN_EOF
#!/bin/bash
ip link del ipsec0 2>/dev/null || true
ip link del ipsec1 2>/dev/null || true
ip route del ${VPNGW_PIP0}/32 via ${NVA_GW} 2>/dev/null || true
ip route del ${VPNGW_PIP1}/32 via ${NVA_GW} 2>/dev/null || true
ip route del throw ${VPNGW_PIP0}/32 table 220 2>/dev/null || true
ip route del throw ${VPNGW_PIP1}/32 table 220 2>/dev/null || true
ip route del ${SUBNET_APP} via ${NVA_GW} 2>/dev/null || true
echo "XFRM interfaces and routes removed"
TEARDOWN_EOF

chmod +x /usr/local/bin/vpn-xfrm-setup.sh
chmod +x /usr/local/bin/vpn-xfrm-teardown.sh

# --- systemd unit ---
cat > /etc/systemd/system/vpn-xfrm.service << 'UNIT_EOF'
[Unit]
Description=VPN XFRM interfaces and routes
After=network-online.target
Before=ipsec.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/vpn-xfrm-setup.sh
ExecStop=/usr/local/bin/vpn-xfrm-teardown.sh

[Install]
WantedBy=multi-user.target
UNIT_EOF

# --- ipsec service override: auto-load swanctl config after charon starts ---
mkdir -p /etc/systemd/system/ipsec.service.d
cat > /etc/systemd/system/ipsec.service.d/swanctl-autoload.conf << 'OVERRIDE_EOF'
[Unit]
After=vpn-xfrm.service
Requires=vpn-xfrm.service

[Service]
ExecStartPost=/bin/bash -c 'sleep 2 && swanctl --load-all'
OVERRIDE_EOF

###############################################################################
# 6. FRR BGP configuration (persistent)
###############################################################################
echo "=== [6/7] Configuring FRR for BGP ==="

# Enable BGP daemon
sed -i 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons

cat > /etc/frr/frr.conf << FRR_EOF
frr defaults traditional
hostname nva
log syslog informational
service integrated-vtysh-config
!
ip route ${ADVERTISE_NETWORK} blackhole
!
router bgp ${NVA_BGP_ASN}
 bgp router-id ${NVA_BGP_IP0}
 no bgp ebgp-requires-policy
 !
 neighbor ${VPNGW_BGP_IP0} remote-as ${VPNGW_BGP_ASN}
 neighbor ${VPNGW_BGP_IP0} description AzVPNGW-instance0
 neighbor ${VPNGW_BGP_IP0} update-source ipsec0
 neighbor ${VPNGW_BGP_IP0} ebgp-multihop 2
 !
 neighbor ${VPNGW_BGP_IP1} remote-as ${VPNGW_BGP_ASN}
 neighbor ${VPNGW_BGP_IP1} description AzVPNGW-instance1
 neighbor ${VPNGW_BGP_IP1} update-source ipsec1
 neighbor ${VPNGW_BGP_IP1} ebgp-multihop 2
 !
 address-family ipv4 unicast
  network ${ADVERTISE_NETWORK}
  neighbor ${VPNGW_BGP_IP0} activate
  neighbor ${VPNGW_BGP_IP0} soft-reconfiguration inbound
  neighbor ${VPNGW_BGP_IP1} activate
  neighbor ${VPNGW_BGP_IP1} soft-reconfiguration inbound
 exit-address-family
!
line vty
!
FRR_EOF

###############################################################################
# 7. Enable and start services
###############################################################################
echo "=== [7/7] Enabling and starting services ==="

systemctl daemon-reload

systemctl enable vpn-xfrm.service
systemctl start  vpn-xfrm.service

systemctl enable ipsec.service
systemctl restart ipsec.service
# swanctl --load-all runs automatically via ExecStartPost override

systemctl enable frr
systemctl restart frr

echo ""
echo "==========================================="
echo "  Configuration complete (reboot-persistent)"
echo "==========================================="
echo ""
echo "Verify with:"
echo "  ip link show ipsec0 ; ip link show ipsec1"
echo "  ip route"
echo "  sudo swanctl --list-sas"
echo "  sudo swanctl --list-conn"
echo "  sudo vtysh -c 'show bgp summary'"
echo "  sudo vtysh -c 'show ip bgp'"
echo ""
echo "Initiate tunnels manually (if needed):"
echo "  sudo swanctl --initiate --ike gw0 --child s2s0"
echo "  sudo swanctl --initiate --ike gw1 --child s2s1"
