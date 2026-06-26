#!/bin/bash
#
# 01-create-certs.sh
#
# Generates the complete X.509 certificate chain for Azure VPN Gateway ↔
# StrongSwan site-to-site authentication using two independent Root CAs.
#
# Certificate Architecture (dual Root CA):
#   RootCA-GW   (RSA 4096, 10yr)  →  signs VPN Gateway leaf cert
#   RootCA-Swan (RSA 4096, 10yr)  →  signs StrongSwan leaf cert
#
# Each side trusts the OTHER side's Root CA:
#   - Azure VPN Gateway trusts RootCA-Swan (inbound cert validation)
#   - StrongSwan trusts RootCA-GW (inbound cert validation)
#
# Steps:
#   1. Generate Root CA key + self-signed cert for VPN Gateway side
#   2. Generate Root CA key + self-signed cert for StrongSwan side
#   3. Generate leaf cert for VPN Gateway (RSA 2048, 2yr), signed by RootCA-GW
#   4. Generate leaf cert for StrongSwan (RSA 2048, 2yr), signed by RootCA-Swan
#   5. Export both leaf certs to PFX (for Azure Key Vault import)
#   6. Export both Root CA certs to DER (for inbound trust configuration)
#
# The script is idempotent — existing keys/certs are skipped (not overwritten).
#
# Prerequisites:
#   - openssl installed
#   - jq installed (for reading init.json)
#
# Output files (in ./certs/):
#   - VPNRootCA-GW.key / .cer / .der    Root CA for VPN Gateway side
#   - VPNRootCA-Swan.key / .cer / .der   Root CA for StrongSwan side
#   - gw1-cert.key / .cer / .pfx         Leaf cert for VPN Gateway (outbound)
#   - swan-cert.key / .cer / .pfx        Leaf cert for StrongSwan (outbound)
#   - cert-pwd.txt                        Password file for PFX exports
#

set -euo pipefail

###############################################################################
# Read parameters from init.json
###############################################################################
pathFiles="$(cd "$(dirname "$0")/.." && pwd)"
inputParamsFile="$pathFiles/init.json"

if [ ! -f "$inputParamsFile" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: Parameters file not found: $inputParamsFile"
    exit 1
fi

certPassword=$(jq -r '.certPassword' "$inputParamsFile")
certRootSubjectGw=$(jq -r '.certRootSubjectGw' "$inputParamsFile")
certRootSubjectSwan=$(jq -r '.certRootSubjectSwan' "$inputParamsFile")
certLeafSubjectGw=$(jq -r '.certLeafSubjectGw' "$inputParamsFile")
certLeafSubjectSwan=$(jq -r '.certLeafSubjectSwan' "$inputParamsFile")

certPath="$pathFiles/certs"
if [ -d "$certPath" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Certificate directory already exists: $certPath"
else
    mkdir -p "$certPath"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Created certificate directory: $certPath"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Certificate output directory: $certPath"
echo "$(date '+%Y-%m-%d %H:%M:%S')"

###############################################################################
# 1. Generate Root CA for VPN Gateway side (RSA 4096-bit, 10-year validity)
###############################################################################
echo "$(date '+%Y-%m-%d %H:%M:%S') - [1/6] Generating Root CA for VPN Gateway: $certRootSubjectGw"
if [ ! -f "$certPath/${certRootSubjectGw}.key" ]; then
    openssl genrsa -out "$certPath/${certRootSubjectGw}.key" 4096

    openssl req -x509 -new -nodes \
        -key "$certPath/${certRootSubjectGw}.key" \
        -sha256 \
        -days 3650 \
        -out "$certPath/${certRootSubjectGw}.cer" \
        -subj "/CN=$certRootSubjectGw" \
        -extensions v3_ca \
        -config <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
[req_distinguished_name]
[v3_ca]
basicConstraints = critical, CA:TRUE, pathlen:4
keyUsage = critical, keyCertSign, cRLSign
EOF
)
    echo "$(date '+%Y-%m-%d %H:%M:%S')   Root CA created: ${certRootSubjectGw}.cer"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S')   Root CA already exists, skipping"
fi

###############################################################################
# 2. Generate Root CA for StrongSwan side (RSA 4096-bit, 10-year validity)
###############################################################################
echo "$(date '+%Y-%m-%d %H:%M:%S') - [2/6] Generating Root CA for StrongSwan: $certRootSubjectSwan"
if [ ! -f "$certPath/${certRootSubjectSwan}.key" ]; then
    openssl genrsa -out "$certPath/${certRootSubjectSwan}.key" 4096

    openssl req -x509 -new -nodes \
        -key "$certPath/${certRootSubjectSwan}.key" \
        -sha256 \
        -days 3650 \
        -out "$certPath/${certRootSubjectSwan}.cer" \
        -subj "/CN=$certRootSubjectSwan" \
        -extensions v3_ca \
        -config <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
[req_distinguished_name]
[v3_ca]
basicConstraints = critical, CA:TRUE, pathlen:4
keyUsage = critical, keyCertSign, cRLSign
EOF
)
    echo "$(date '+%Y-%m-%d %H:%M:%S')   Root CA created: ${certRootSubjectSwan}.cer"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S')   Root CA already exists, skipping"
fi

###############################################################################
# 3. Generate Leaf Certificate for VPN Gateway (signed by Root CA GW)
###############################################################################
echo "$(date '+%Y-%m-%d %H:%M:%S') - [3/6] Generating leaf certificate for VPN Gateway: $certLeafSubjectGw"
if [ ! -f "$certPath/${certLeafSubjectGw}.key" ]; then
    # Generate private key (RSA 2048-bit)
    openssl genrsa -out "$certPath/${certLeafSubjectGw}.key" 2048

    # Generate CSR
    openssl req -new \
        -key "$certPath/${certLeafSubjectGw}.key" \
        -out "$certPath/${certLeafSubjectGw}.csr" \
        -subj "/CN=$certLeafSubjectGw"

    # Sign with Root CA GW (2-year validity)
    openssl x509 -req \
        -in "$certPath/${certLeafSubjectGw}.csr" \
        -CA "$certPath/${certRootSubjectGw}.cer" \
        -CAkey "$certPath/${certRootSubjectGw}.key" \
        -CAcreateserial \
        -out "$certPath/${certLeafSubjectGw}.cer" \
        -days 730 \
        -sha256 \
        -extfile <(cat <<EOF
extendedKeyUsage = clientAuth, serverAuth
EOF
)
    echo "$(date '+%Y-%m-%d %H:%M:%S')   Leaf cert created: ${certLeafSubjectGw}.cer"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S')   Leaf cert already exists, skipping"
fi

###############################################################################
# 4. Generate Leaf Certificate for StrongSwan (signed by Root CA Swan)
###############################################################################
echo "$(date '+%Y-%m-%d %H:%M:%S') - [4/6] Generating leaf certificate for StrongSwan: $certLeafSubjectSwan"
if [ ! -f "$certPath/${certLeafSubjectSwan}.key" ]; then
    # Generate private key (RSA 2048-bit)
    openssl genrsa -out "$certPath/${certLeafSubjectSwan}.key" 2048

    # Generate CSR
    openssl req -new \
        -key "$certPath/${certLeafSubjectSwan}.key" \
        -out "$certPath/${certLeafSubjectSwan}.csr" \
        -subj "/CN=$certLeafSubjectSwan"

    # Sign with Root CA Swan (2-year validity)
    openssl x509 -req \
        -in "$certPath/${certLeafSubjectSwan}.csr" \
        -CA "$certPath/${certRootSubjectSwan}.cer" \
        -CAkey "$certPath/${certRootSubjectSwan}.key" \
        -CAcreateserial \
        -out "$certPath/${certLeafSubjectSwan}.cer" \
        -days 730 \
        -sha256 \
        -extfile <(cat <<EOF
extendedKeyUsage = clientAuth, serverAuth
EOF
)
    echo "$(date '+%Y-%m-%d %H:%M:%S')   Leaf cert created: ${certLeafSubjectSwan}.cer"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S')   Leaf cert already exists, skipping"
fi

###############################################################################
# 5. Export leaf certificates to PFX format (for Azure Key Vault import)
###############################################################################
echo "$(date '+%Y-%m-%d %H:%M:%S') - [5/6] Exporting leaf certificates to PFX format"

# VPN Gateway leaf cert → PFX
openssl pkcs12 -export \
    -out "$certPath/${certLeafSubjectGw}.pfx" \
    -inkey "$certPath/${certLeafSubjectGw}.key" \
    -in "$certPath/${certLeafSubjectGw}.cer" \
    -certfile "$certPath/${certRootSubjectGw}.cer" \
    -passout "pass:$certPassword"
echo "$(date '+%Y-%m-%d %H:%M:%S')   Exported: ${certLeafSubjectGw}.pfx"

# StrongSwan leaf cert → PFX
openssl pkcs12 -export \
    -out "$certPath/${certLeafSubjectSwan}.pfx" \
    -inkey "$certPath/${certLeafSubjectSwan}.key" \
    -in "$certPath/${certLeafSubjectSwan}.cer" \
    -certfile "$certPath/${certRootSubjectSwan}.cer" \
    -passout "pass:$certPassword"
echo "$(date '+%Y-%m-%d %H:%M:%S')   Exported: ${certLeafSubjectSwan}.pfx"

###############################################################################
# 6. Export Root CA certs in DER format (for inbound certificate config)
###############################################################################
echo "$(date '+%Y-%m-%d %H:%M:%S') - [6/6] Exporting Root CA certificates in DER format"

openssl x509 -in "$certPath/${certRootSubjectGw}.cer" \
    -outform DER -out "$certPath/${certRootSubjectGw}.der"
echo "$(date '+%Y-%m-%d %H:%M:%S')   Exported: ${certRootSubjectGw}.der"

openssl x509 -in "$certPath/${certRootSubjectSwan}.cer" \
    -outform DER -out "$certPath/${certRootSubjectSwan}.der"
echo "$(date '+%Y-%m-%d %H:%M:%S')   Exported: ${certRootSubjectSwan}.der"

###############################################################################
# Write password file
###############################################################################
cat > "$certPath/cert-pwd.txt" <<EOF
certificate: ${certLeafSubjectGw}.pfx, password: $certPassword
certificate: ${certLeafSubjectSwan}.pfx, password: $certPassword
EOF

echo "$(date '+%Y-%m-%d %H:%M:%S')"
echo " ==========================================="
echo "   Certificate generation complete!"
echo " ==========================================="
echo ""
echo "$(date '+%Y-%m-%d %H:%M:%S') Generated files in $certPath:"
ls -la "$certPath"
