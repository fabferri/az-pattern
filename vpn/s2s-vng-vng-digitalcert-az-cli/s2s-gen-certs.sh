#!/bin/bash
# Script to create the Root Certificates and leaf Certificates signed with root certificates.
# This script uses OpenSSL and can run on Linux/macOS/WSL
#
# Input parameters:
#   $1: password for certificates (default: 12345)

pwdCertificates="${1:-12345}"

certRootSubject1='VPNRootCA1'
certRootSubject2='VPNRootCA2'
certLeafSubject1='s2s-cert1'
certLeafSubject2='s2s-cert2'

# The variable specifies the local folder to store the digital certificates
pathFiles="$(dirname "$0")"
certPath="$pathFiles/certs/"

echo "folder to store digital certificates: $certPath"

# Create a local folder: ./certs/
mkdir -p "$certPath"
echo ''

# Generate Root Certificate 1
echo "$(date) - checking Root certificate $certRootSubject1"
if [ ! -f "$certPath${certRootSubject1}.key" ]; then
    echo "$(date) - Creating Root Certificate: $certRootSubject1"
    
    # Generate private key
    openssl genrsa -out "$certPath${certRootSubject1}.key" 2048
    
    # Generate self-signed root certificate
    openssl req -x509 -new -nodes \
        -key "$certPath${certRootSubject1}.key" \
        -sha256 \
        -days 3650 \
        -out "$certPath${certRootSubject1}.cer" \
        -subj "/CN=$certRootSubject1" \
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
    echo "$(date) - Root certificate $certRootSubject1 created"
else
    echo "$(date) - Root certificate $certRootSubject1 already exists, skipping"
fi

# Save root certificate in DER format (.cert)
if [ ! -f "$certPath${certRootSubject1}.cert" ]; then
    openssl x509 -in "$certPath${certRootSubject1}.cer" -outform DER -out "$certPath${certRootSubject1}.cert"
    echo "$(date) - Created the file: $certPath${certRootSubject1}.cert"
fi

# Generate Root Certificate 2
echo "$(date) - checking Root certificate $certRootSubject2"
if [ ! -f "$certPath${certRootSubject2}.key" ]; then
    echo "$(date) - Creating Root Certificate: $certRootSubject2"
    
    # Generate private key
    openssl genrsa -out "$certPath${certRootSubject2}.key" 2048
    
    # Generate self-signed root certificate
    openssl req -x509 -new -nodes \
        -key "$certPath${certRootSubject2}.key" \
        -sha256 \
        -days 3650 \
        -out "$certPath${certRootSubject2}.cer" \
        -subj "/CN=$certRootSubject2" \
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
    echo "$(date) - Root certificate $certRootSubject2 created"
else
    echo "$(date) - Root certificate $certRootSubject2 already exists, skipping"
fi

# Save root certificate in DER format (.cert)
if [ ! -f "$certPath${certRootSubject2}.cert" ]; then
    openssl x509 -in "$certPath${certRootSubject2}.cer" -outform DER -out "$certPath${certRootSubject2}.cert"
    echo "$(date) - Created the file: $certPath${certRootSubject2}.cert"
fi

# Generate Leaf Certificate 1 (signed by Root CA 1)
echo "$(date) - start creation leaf cert: $certLeafSubject1"
if [ ! -f "$certPath${certLeafSubject1}.key" ]; then
    # Generate private key
    openssl genrsa -out "$certPath${certLeafSubject1}.key" 2048
    
    # Generate CSR
    openssl req -new \
        -key "$certPath${certLeafSubject1}.key" \
        -out "$certPath${certLeafSubject1}.csr" \
        -subj "/CN=$certLeafSubject1"
    
    # Sign with Root CA 1
    openssl x509 -req \
        -in "$certPath${certLeafSubject1}.csr" \
        -CA "$certPath${certRootSubject1}.cer" \
        -CAkey "$certPath${certRootSubject1}.key" \
        -CAcreateserial \
        -out "$certPath${certLeafSubject1}.cer" \
        -days 3650 \
        -sha256 \
        -extfile <(cat <<EOF
extendedKeyUsage = clientAuth, serverAuth
EOF
)
    echo "$(date) - Leaf cert: $certLeafSubject1 created"
else
    echo "$(date) - Leaf cert: $certLeafSubject1 already exists, skipping..."
fi

# Export leaf certificate 1 to PFX
echo "$(date) - Exporting $certLeafSubject1 to PFX format"
openssl pkcs12 -export \
    -out "$certPath${certLeafSubject1}.pfx" \
    -inkey "$certPath${certLeafSubject1}.key" \
    -in "$certPath${certLeafSubject1}.cer" \
    -certfile "$certPath${certRootSubject1}.cer" \
    -passout "pass:$pwdCertificates"

# Generate Leaf Certificate 2 (signed by Root CA 2)
echo "$(date) - start creation leaf cert: $certLeafSubject2"
if [ ! -f "$certPath${certLeafSubject2}.key" ]; then
    # Generate private key
    openssl genrsa -out "$certPath${certLeafSubject2}.key" 2048
    
    # Generate CSR
    openssl req -new \
        -key "$certPath${certLeafSubject2}.key" \
        -out "$certPath${certLeafSubject2}.csr" \
        -subj "/CN=$certLeafSubject2"
    
    # Sign with Root CA 2
    openssl x509 -req \
        -in "$certPath${certLeafSubject2}.csr" \
        -CA "$certPath${certRootSubject2}.cer" \
        -CAkey "$certPath${certRootSubject2}.key" \
        -CAcreateserial \
        -out "$certPath${certLeafSubject2}.cer" \
        -days 3650 \
        -sha256 \
        -extfile <(cat <<EOF
extendedKeyUsage = clientAuth, serverAuth
EOF
)
    echo "$(date) - Leaf cert: $certLeafSubject2 created"
else
    echo "$(date) - Leaf cert: $certLeafSubject2 already exists, skipping..."
fi

# Export leaf certificate 2 to PFX
echo "$(date) - Exporting $certLeafSubject2 to PFX format"
openssl pkcs12 -export \
    -out "$certPath${certLeafSubject2}.pfx" \
    -inkey "$certPath${certLeafSubject2}.key" \
    -in "$certPath${certLeafSubject2}.cer" \
    -certfile "$certPath${certRootSubject2}.cer" \
    -passout "pass:$pwdCertificates"

# Create password file
pwdFile="$certPath/cert-pwd.txt"
echo "Created a file to store password for certificates"
echo "certificate: $certLeafSubject1, password: $pwdCertificates" > "$pwdFile"
echo "certificate: $certLeafSubject2, password: $pwdCertificates" >> "$pwdFile"

echo ""
echo "$(date) - Certificate generation complete!"
echo "Generated files in $certPath:"
ls -la "$certPath"
