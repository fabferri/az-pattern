#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Compute
<#
.SYNOPSIS
    Configures an Ubuntu 24.04 NVA as a strongSwan IPsec gateway remotely.

.DESCRIPTION
    This script performs three main steps:
      1. Uploads X.509 certificate files to the NVA via SCP.
      2. Builds a comprehensive bash configuration script in-memory (with all
         variables interpolated from PowerShell), saves a local copy as
         'configure-strongswan-nva.sh' in the scripts-ps folder, then executes
         it on the NVA via Invoke-AzVMRunCommand.
      3. Displays the remote execution output and prints verification commands.

    The generated bash script configures:
      - Package installation (strongswan, strongswan-swanctl, frr)
      - Sysctl settings (IP forwarding, disable redirects, relaxed rp_filter)
      - strongSwan charon (install_routes = no)
      - swanctl.conf with two IKEv2 connections (gw0, gw1) using X.509 certs,
        GCMAES256 proposals, XFRM if_id binding, and auto-restart on failure
      - XFRM interfaces (ipsec0, ipsec1) via a systemd oneshot service with
        BGP source IPs, host routes for VPN GW peers, and throw routes in table 220
      - FRR BGP peering with both VPN Gateway instances over XFRM interfaces
      - Service boot order: network-online -> vpn-xfrm -> ipsec -> frr

    All configuration is reboot-persistent (systemd services + config files).

.NOTES
    Prerequisites:
      - Az PowerShell modules installed and logged in
      - SSH client on PATH (for SCP file transfer)
      - Fill in variables below from 02-deploy-azure.ps1 output
        (or run 02b-generate-strongswan-vars.ps1 to auto-populate)
      - Certificate files available in ./certs/

    Certificate files required on NVA:
      - swan-cert.cer        -> /etc/swanctl/x509/
      - swan-cert.key        -> /etc/swanctl/private/
      - VPNRootCA-GW.cer     -> /etc/swanctl/x509ca/
      - VPNRootCA-Swan.cer   -> /etc/swanctl/x509ca/
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Log { param([string]$Message) Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" }

###############################################################################
# Variables — fill these from 02-deploy-azure.ps1 output
###############################################################################

# NVA network settings (single NIC: management + IPsec on eth0)
$NVA_PRIVATE_IP = "10.2.0.10"                 # NVA single NIC private IP
$NVA_PUBLIC_IP  = "192.0.2.1"                   # NVA public IP (Azure-assigned)
$NVA_IFACE     = "eth0"                       # NVA interface name
$NVA_GW        = "10.2.0.1"                   # Default gateway for NVA subnet
# NVA BGP settings
$NVA_BGP_ASN = 65020                          # NVA BGP ASN
$NVA_BGP_IP0 = "192.168.0.1"                  # BGP source IP on ipsec0
$NVA_BGP_IP1 = "192.168.0.2"                  # BGP source IP on ipsec1
# Azure VPN Gateway settings (from 02-deploy-azure.ps1 output)
$VPNGW_PIP0    = "198.51.100.1"                    # VPN GW instance 0 public IP
$VPNGW_PIP1    = "198.51.100.2"                    # VPN GW instance 1 public IP
$VPNGW_BGP_IP0 = "10.1.0.4"                   # VPN GW instance 0 BGP IP
$VPNGW_BGP_IP1 = "10.1.0.5"                   # VPN GW instance 1 BGP IP
$VPNGW_BGP_ASN = 65010                        # VPN GW BGP ASN
# XFRM interface IDs
$XFRM_IF_ID0 = 41
$XFRM_IF_ID1 = 42

# Network to advertise via BGP
$ADVERTISE_NETWORK = "10.2.0.0/16"

# Additional local subnets
$SUBNET_APP = "10.2.1.0/24"

# Optional SNAT
$ENABLE_SNAT = "false"
$REMOTE_NETWORK = "10.1.0.0/16"

# Certificate settings
$CERT_LEAF_NAME  = "swan-cert"                # StrongSwan leaf certificate CN
$CERT_LEAF_GW   = "gw1-cert"                  # Azure VPN Gateway leaf certificate CN
$CERT_ROOT_GW   = "VPNRootCA-GW"              # Azure VPN Gateway Root CA name
$CERT_ROOT_SWAN = "VPNRootCA-Swan"             # StrongSwan's own Root CA name
###############################################################################
# Read parameters from init.json
###############################################################################
$pathFiles = Split-Path -Parent $PSScriptRoot
$inputParamsFile = Join-Path $pathFiles 'init.json'

if (-not (Test-Path $inputParamsFile)) {
    Write-Error "Parameters file not found: $inputParamsFile"
    exit 1
}

$params = Get-Content $inputParamsFile -Raw | ConvertFrom-Json
$subscriptionName = $params.subscriptionName
$rgName           = $params.rgName
$adminUsername    = $params.adminUsername
$nvaVmName       = $params.nvaVmName

$certPath = Join-Path $pathFiles 'certs'

Set-AzContext -Subscription $subscriptionName | Out-Null

###############################################################################
# Step 1: Generate configure-strongswan-nva.sh locally
###############################################################################
Log ">>> [1/3] Generating configure-strongswan-nva.sh locally"

# Verify certificate files exist
$certFiles = @(
    "$CERT_LEAF_NAME.cer",
    "$CERT_LEAF_NAME.key",
    "$CERT_ROOT_GW.cer",
    "$CERT_ROOT_SWAN.cer"
)

foreach ($f in $certFiles) {
    $filePath = Join-Path $certPath $f
    if (-not (Test-Path $filePath)) {
        Write-Error "Certificate file not found: $filePath"
        exit 1
    }
}
Log "  Certificate files verified."

# Build the complete bash configuration script to run on the NVA
# NOTE: The header uses @"..."@ (expandable) to bake PowerShell values into bash variables.
#       The body uses @'...'@ (verbatim) so bash $variable references pass through literally.
$configScriptHeader = @"
#!/bin/bash
set -euo pipefail

# Variables
NVA_PRIVATE_IP="$NVA_PRIVATE_IP"
NVA_PUBLIC_IP="$NVA_PUBLIC_IP"
NVA_IFACE="$NVA_IFACE"
NVA_GW="$NVA_GW"
NVA_BGP_ASN=$NVA_BGP_ASN
NVA_BGP_IP0="$NVA_BGP_IP0"
NVA_BGP_IP1="$NVA_BGP_IP1"
VPNGW_PIP0="$VPNGW_PIP0"
VPNGW_PIP1="$VPNGW_PIP1"
VPNGW_BGP_IP0="$VPNGW_BGP_IP0"
VPNGW_BGP_IP1="$VPNGW_BGP_IP1"
VPNGW_BGP_ASN=$VPNGW_BGP_ASN
XFRM_IF_ID0=$XFRM_IF_ID0
XFRM_IF_ID1=$XFRM_IF_ID1
ADVERTISE_NETWORK="$ADVERTISE_NETWORK"
SUBNET_APP="$SUBNET_APP"
ENABLE_SNAT="$ENABLE_SNAT"
REMOTE_NETWORK="$REMOTE_NETWORK"
CERT_LEAF_NAME="$CERT_LEAF_NAME"
CERT_LEAF_GW="$CERT_LEAF_GW"
CERT_ROOT_GW="$CERT_ROOT_GW"
CERT_ROOT_SWAN="$CERT_ROOT_SWAN"
CERT_SRC="/home/$adminUsername/certs"
"@

$configScriptBody = @'

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
'@

# Combine header (with baked-in values) + body (verbatim bash code)
$configScript = ($configScriptHeader + "`n" + $configScriptBody) -replace "`r`n", "`n"

# Save the generated bash script locally (Unix line endings)
$localCopyPath = Join-Path $PSScriptRoot 'configure-strongswan-nva.sh'
[System.IO.File]::WriteAllText($localCopyPath, $configScript, [System.Text.UTF8Encoding]::new($false))
Log "  Generated: $localCopyPath"
Log "  You can also run this script manually on the NVA with: sudo bash ~/configure-strongswan-nva.sh"

###############################################################################
# Step 2: Upload certificates to NVA via Invoke-AzVMRunCommand (no SSH/password)
###############################################################################
$proceed = Read-Host "Do you want to proceed with certificate upload and remote configuration? (y/N)"
if ($proceed -notin @('y', 'Y', 'yes', 'Yes')) {
    Log "  Skipping remote configuration."
    Log "  To run manually on the NVA:"
    Log "    scp certs/* ${adminUsername}@${NVA_PUBLIC_IP}:~/certs/"
    Log "    scp $localCopyPath ${adminUsername}@${NVA_PUBLIC_IP}:~/"
    Log "    ssh ${adminUsername}@${NVA_PUBLIC_IP} 'sudo bash ~/configure-strongswan-nva.sh'"
    exit 0
}

Log ">>> [2/3] Uploading certificates to NVA via Invoke-AzVMRunCommand (no SSH/password needed)"

# Base64-encode each cert file and build a bash script that decodes them on the VM
$certUploadLines = @(
    '#!/bin/bash'
    'set -euo pipefail'
    "mkdir -p /home/${adminUsername}/certs"
)

foreach ($f in $certFiles) {
    $filePath = Join-Path $certPath $f
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePath))
    $certUploadLines += "echo '${b64}' | base64 -d > /home/${adminUsername}/certs/${f}"
}

$certUploadLines += @(
    "chown -R ${adminUsername}:${adminUsername} /home/${adminUsername}/certs"
    'echo "Certificates decoded and installed:"'
    "ls -la /home/${adminUsername}/certs/"
)

$certUploadScript = $certUploadLines -join "`n"
$certResult = Invoke-AzVMRunCommand -ResourceGroupName $rgName -VMName $nvaVmName `
    -CommandId 'RunShellScript' -ScriptString $certUploadScript

foreach ($output in $certResult.Value) {
    if ($output.Message) { Write-Host $output.Message }
}
Log "  Certificates uploaded via Azure VM Run Command"

###############################################################################
# Step 3: Execute configuration script on NVA via Invoke-AzVMRunCommand
###############################################################################
$runRemote = Read-Host "Do you want to execute the configuration script on the NVA? (y/N)"
if ($runRemote -notin @('y', 'Y', 'yes', 'Yes')) {
    Log "  Skipping remote execution."
    Log "  Script saved locally at: $localCopyPath"
    exit 0
}

Log ">>> [3/3] Running configuration on NVA via Invoke-AzVMRunCommand (this may take several minutes)..."

# Base64-encode the config script, decode on VM, save as executable, then run it
$configB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($configScript))
$wrapperScript = @"
#!/bin/bash
set -euo pipefail
echo '${configB64}' | base64 -d > /home/${adminUsername}/configure-strongswan-nva.sh
dos2unix /home/${adminUsername}/configure-strongswan-nva.sh 2>/dev/null || sed -i 's/\r$//' /home/${adminUsername}/configure-strongswan-nva.sh
chmod +x /home/${adminUsername}/configure-strongswan-nva.sh
chown ${adminUsername}:${adminUsername} /home/${adminUsername}/configure-strongswan-nva.sh
echo "Script saved to /home/${adminUsername}/configure-strongswan-nva.sh (chmod +x, dos2unix applied)"
sudo /home/${adminUsername}/configure-strongswan-nva.sh
"@

$execResult = Invoke-AzVMRunCommand -ResourceGroupName $rgName -VMName $nvaVmName `
    -CommandId 'RunShellScript' -ScriptString $wrapperScript

foreach ($output in $execResult.Value) {
    if ($output.Message) { Write-Host $output.Message }
}

###############################################################################
# Summary
###############################################################################
Log "  Configuration complete"
Log " "
Log "==========================================="
Log "  StrongSwan NVA Configuration Complete"
Log "==========================================="
Log " "
Log "Boot order: network-online -> vpn-xfrm -> ipsec (+ swanctl --load-all) -> frr"
Log " "
Log "Verify with:"
Log "  ssh ${adminUsername}@${NVA_PUBLIC_IP}"
Log "  sudo swanctl --list-sas"
Log "  sudo swanctl --list-conns"
Log "  sudo vtysh -c 'show bgp summary'"
Log "  sudo vtysh -c 'show ip bgp'"
