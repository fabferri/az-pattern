#!/bin/bash
set -euo pipefail

# Variables
NVA_PRIVATE_IP="10.2.0.10"
NVA_PUBLIC_IP="192.0.2.1"
NVA_IFACE="eth0"
NVA_GW="10.2.0.1"
NVA_BGP_ASN=65020
NVA_BGP_IP0="192.168.0.1"
NVA_BGP_IP1="192.168.0.2"
VPNGW_PIP0="198.51.100.1"
VPNGW_PIP1="198.51.100.2"
VPNGW_BGP_IP0="10.1.0.4"
VPNGW_BGP_IP1="10.1.0.5"
VPNGW_BGP_ASN=65010
XFRM_IF_ID0=41
XFRM_IF_ID1=42
ADVERTISE_NETWORK="10.2.0.0/16"
SUBNET_APP="10.2.1.0/24"
ENABLE_SNAT="false"
REMOTE_NETWORK="10.1.0.0/16"
CERT_LEAF_NAME="swan-cert"
CERT_LEAF_GW="gw1-cert"
CERT_ROOT_GW="VPNRootCA-GW"
CERT_ROOT_SWAN="VPNRootCA-Swan"
CERT_SRC="/home/edge/certs"

###############################################################################
# 1. Install packages
###############################################################################
echo ">>> [1/7] Installing packages"
apt-get update -qq
apt-get install -y strongswan strongswan-swanctl libcharon-extra-plugins frr net-tools dos2unix

###############################################################################
# 2. Persistent sysctl
###############################################################################
echo ">>> [2/7] Configuring sysctl (persistent)"
cat > /etc/sysctl.d/60-vpn.conf << 'SYSCTL_EOF'
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.eth0.rp_filter = 0
SYSCTL_EOF
sysctl --system > /dev/null 2>&1

###############################################################################
# 3. strongSwan charon — disable automatic route installation
###############################################################################
echo ">>> [3/7] Configuring strongSwan charon"
if grep -q 'install_routes = no' /etc/strongswan.d/charon.conf 2>/dev/null; then
    echo "  charon install_routes already set to no, skipping"
elif grep -q '# install_routes = yes' /etc/strongswan.d/charon.conf 2>/dev/null; then
    sed -i 's/# install_routes = yes/install_routes = no/' /etc/strongswan.d/charon.conf
elif grep -q 'install_routes = yes' /etc/strongswan.d/charon.conf 2>/dev/null; then
    sed -i 's/install_routes = yes/install_routes = no/' /etc/strongswan.d/charon.conf
else
    echo "charon { install_routes = no }" >> /etc/strongswan.d/charon.conf
fi

###############################################################################
# 4. Install certificates and write swanctl.conf
###############################################################################
echo ">>> [4/7] Writing /etc/swanctl/swanctl.conf"
mkdir -p /etc/swanctl/x509 /etc/swanctl/x509ca /etc/swanctl/private

for f in "${CERT_LEAF_NAME}.cer" "${CERT_LEAF_NAME}.key" "${CERT_ROOT_GW}.cer" "${CERT_ROOT_SWAN}.cer"; do
    if [ ! -f "$CERT_SRC/$f" ]; then
        echo "ERROR: certificate file not found: $CERT_SRC/$f"
        exit 1
    fi
done

install -m 0644 "$CERT_SRC/${CERT_LEAF_NAME}.cer" "/etc/swanctl/x509/${CERT_LEAF_NAME}.cer"
install -m 0600 "$CERT_SRC/${CERT_LEAF_NAME}.key" "/etc/swanctl/private/${CERT_LEAF_NAME}.key"
install -m 0644 "$CERT_SRC/${CERT_ROOT_GW}.cer"   "/etc/swanctl/x509ca/${CERT_ROOT_GW}.cer"
install -m 0644 "$CERT_SRC/${CERT_ROOT_SWAN}.cer" "/etc/swanctl/x509ca/${CERT_ROOT_SWAN}.cer"

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
            auth = pubkey
            id = "CN=${CERT_LEAF_NAME}"
            certs = ${CERT_LEAF_NAME}.cer
        }
        remote {
            auth = pubkey
            id = "CN=${CERT_LEAF_GW}"
            cacerts = ${CERT_ROOT_GW}.cer
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
            auth = pubkey
            id = "CN=${CERT_LEAF_NAME}"
            certs = ${CERT_LEAF_NAME}.cer
        }
        remote {
            auth = pubkey
            id = "CN=${CERT_LEAF_GW}"
            cacerts = ${CERT_ROOT_GW}.cer
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
SWAN_EOF

###############################################################################
# 5. XFRM interfaces + routes — systemd service
###############################################################################
echo ">>> [5/7] Creating XFRM systemd service"

cat > /usr/local/bin/vpn-xfrm-setup.sh << SETUP_EOF
#!/bin/bash
set -e
# Remove existing XFRM interfaces (idempotent)
ip link del ipsec0 2>/dev/null || true
ip link del ipsec1 2>/dev/null || true
# Create XFRM interfaces
ip link add ipsec0 type xfrm dev ${NVA_IFACE} if_id ${XFRM_IF_ID0}
ip addr add ${NVA_BGP_IP0}/32 dev ipsec0
ip link set ipsec0 up
ip link add ipsec1 type xfrm dev ${NVA_IFACE} if_id ${XFRM_IF_ID1}
ip addr add ${NVA_BGP_IP1}/32 dev ipsec1
ip link set ipsec1 up
# Routes (use replace for idempotency)
ip route replace ${VPNGW_BGP_IP0}/32 dev ipsec0
ip route replace ${VPNGW_BGP_IP1}/32 dev ipsec1
ip route replace ${VPNGW_PIP0}/32 via ${NVA_GW}
ip route replace ${VPNGW_PIP1}/32 via ${NVA_GW}
ip route replace throw ${VPNGW_PIP0}/32 table 220
ip route replace throw ${VPNGW_PIP1}/32 table 220
ip route replace ${SUBNET_APP} via ${NVA_GW}
if [ "${ENABLE_SNAT}" = "true" ]; then
    iptables -t nat -C POSTROUTING -s ${REMOTE_NETWORK} -o ${NVA_IFACE} -j MASQUERADE 2>/dev/null \
        || iptables -t nat -A POSTROUTING -s ${REMOTE_NETWORK} -o ${NVA_IFACE} -j MASQUERADE
fi
echo "XFRM interfaces and routes configured"
SETUP_EOF

cat > /usr/local/bin/vpn-xfrm-teardown.sh << TEARDOWN_EOF
#!/bin/bash
ip link del ipsec0 2>/dev/null || true
ip link del ipsec1 2>/dev/null || true
ip route del ${VPNGW_PIP0}/32 via ${NVA_GW} 2>/dev/null || true
ip route del ${VPNGW_PIP1}/32 via ${NVA_GW} 2>/dev/null || true
ip route del throw ${VPNGW_PIP0}/32 table 220 2>/dev/null || true
ip route del throw ${VPNGW_PIP1}/32 table 220 2>/dev/null || true
ip route del ${SUBNET_APP} via ${NVA_GW} 2>/dev/null || true
iptables -t nat -D POSTROUTING -s ${REMOTE_NETWORK} -o ${NVA_IFACE} -j MASQUERADE 2>/dev/null || true
echo "XFRM interfaces and routes removed"
TEARDOWN_EOF

chmod +x /usr/local/bin/vpn-xfrm-setup.sh
chmod +x /usr/local/bin/vpn-xfrm-teardown.sh

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

mkdir -p /etc/systemd/system/ipsec.service.d
cat > /etc/systemd/system/ipsec.service.d/swanctl-autoload.conf << 'OVERRIDE_EOF'
[Unit]
After=vpn-xfrm.service
Wants=vpn-xfrm.service

[Service]
ExecStartPost=/bin/bash -c 'for i in $(seq 1 30); do swanctl --load-all && exit 0; sleep 1; done; exit 0'
OVERRIDE_EOF

###############################################################################
# 6. FRR BGP configuration
###############################################################################
echo ">>> [6/7] Configuring FRR for BGP"
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
echo ">>> [7/7] Enabling and starting services"
systemctl daemon-reload
systemctl enable vpn-xfrm.service
systemctl start vpn-xfrm.service
systemctl enable ipsec.service
systemctl restart ipsec.service
systemctl enable frr
systemctl restart frr

echo ""
echo "==========================================="
echo "  Configuration complete (reboot-persistent)"
echo "==========================================="
echo ""
echo "Verify with:"
echo "  ip link show ipsec0 ; ip link show ipsec1"
echo "  sudo swanctl --list-sas"
echo "  sudo vtysh -c 'show bgp summary'"