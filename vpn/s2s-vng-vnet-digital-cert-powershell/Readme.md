# Azure Site-to-Site VPN with Digital Certificate Authentication

## Description

This project creates a Site-to-Site (S2S) VPN connection between two Azure Virtual Networks (VNets) using digital certificate-based authentication.

The VPN tunnels are secured using X.509 certificates instead of pre-shared keys, providing stronger security compared to pre-shared keys for the VPN connection.

---

## Project Structure

```
├── 01_vpn1.ps1          - Creates the first VPN Gateway and VNet
├── 02_vpn2.ps1          - Creates the second VPN Gateway and VNet
├── 03_vpn-conn.ps1      - Establishes the S2S VPN connection between the two VNets
├── 04_vms.ps1           - Deploys Virtual Machines in the VNets for testing
├── s2s-gen-certs.ps1    - Generates the digital certificates for VPN authentication
├── init.json            - Configuration/initialization parameters (subscription name, resouce group name, administrator username and password for the VMs)
└── certs/               - Folder containing the generated certificates
    ├── cert-pwd.txt     - Password to access to the .pfx files
    ├── s2s-cert1.pfx    - PKCS#12 leaf certificate bundle for VPN Gateway 1 (contains private key)
    ├── s2s-cert2.pfx    - PKCS#12 leaf certificate bundle for VPN Gateway 2 (contains private key)
    ├── VPNRootCA1.cer   - self-signed Root CA certificate for VPN Gateway 1 in DER binary format
    ├── VPNRootCA1.cert  - self-signed Root CA certificate for VPN Gateway 1 in Base64 encoded format
    ├── VPNRootCA2.cer   - self-signed Root CA certificate for VPN Gateway 2 in DER binary format
    └── VPNRootCA2.cert  - self-signed Root CA certificate for VPN Gateway 2 in Base64 encoded format
```


---

## Execution Order

Before running the deployment scripts, generate the certificates using:

```powershell
.\s2s-gen-certs.ps1
```

[![1]][1]

This script creates the self-sign root CA certificates and clients certificate required for VPN authentication; the digital certificates are stored in the `.\certs` folder.

[![2]][2]

After generations of the digital certificates, run the scripts in the following sequence:

1. **Step 1:** `.\01_vpn1.ps1` - Deploy first VNet and VPN Gateway
1. **Step 2:** `.\02_vpn2.ps1` - Deploy second VNet and VPN Gateway
1. **Step 3:** `.\03_vpn-conn.ps1` - Create the S2S VPN connection
1. **Step 4:** `.\04_vms.ps1` - Deploy test VMs in both VNets

> [!NOTE]
> VPN Gateway deployment can take 30-45 minutes. The scripts `01_vpn1.ps1` and `02_vpn2.ps1` can run in parallel because they are independent. 
> However, `03_vpn-conn.ps1` has dependencies on both scripts and can only be executed after the successful completion of both `01_vpn1.ps1` and `02_vpn2.ps1`.

---


## Architecture Overview

This project uses digital certificate authentication for the S2S VPN tunnels. The digital certificates are securely stored in Azure Key Vault, and each VPN Gateway accesses its certificates through a User-Assigned Managed Identity.

[![3]][3]

For Key Vault access control, this project implements Role-Based Access Control (RBAC) rather than the legacy Access Policy model. Microsoft has officially referred to Access Policies as "legacy since 2022" and recommends that all customers migrate to RBAC for improved security and governance.

The pictures shows the import if leaf certificates in KeyVaults:

[![4]][4]

Site-to-site certificate authentication relies on both **inbound** and **outbound** certificates to establish secure VPN tunnels between Azure and on-premises (or between two Azure VPN Gateways).

### Certificate Types and Their Purpose

| Certificate Type                | Purpose | Storage | Contains Private Key |
|---------------------------------|---------|---------|----------------------|
| **Root CA Certificate**         | Self-signed certificate used to sign leaf certificates. Establishes the trust chain. | Local (used for signing) | Yes |
| **Outbound Certificate (Leaf)** | Used to verify connections going **from Azure to the remote site**. Signed by the Root CA. | Azure Key Vault (.pfx) | Yes |
| **Inbound Certificate (Leaf)**  | Used when connecting **from the remote site to Azure**. The public key is configured in the VPN connection. | Connection configuration (.cer) | No (public key only) |

### How Certificate Authentication Works

1. **Root CA Certificates** (`VPNRootCA1`, `VPNRootCA2`) are self-signed certificates created using `New-SelfSignedCertificate` with `KeyUsage = 'CertSign'`. They act as the trust anchor.

2. **Leaf Certificates** (`s2s-cert1.pfx`, `s2s-cert2.pfx`) are generated and signed by the corresponding Root CA certificate. They include:
   - Server and client authentication extended key usage
   - Minimum 2048-bit key length
   - Private key (required for outbound authentication)

3. **Outbound Certificate Flow** (Azure to Remote):
   - The outbound certificate (.pfx with private key) is stored in Azure Key Vault
   - The VPN Gateway accesses this certificate via its User-Assigned Managed Identity
   - When establishing the tunnel, the gateway presents this certificate to authenticate itself to the remote peer

4. **Inbound Certificate Flow** (Remote to Azure):
   - The inbound certificate's public key (.cer) is configured in the VPN connection settings
   - The remote VPN device presents its certificate
   - Azure validates the certificate chain against the configured inbound certificate chain

#### Project certificate mapping

Each VPN Gateway is configured with its own <ins>User-Assigned Managed Identity</ins> to securely access certificates stored in Azure Key Vault:

| VPN Gateway | User Managed Identity | Key Vault       | Outbound Certificate (Key Vault) | Inbound Certificate Chain |
|-------------|-----------------------|-----------------|----------------------------------|---------------------------|
| gw1         | gw1-s2s-kv            | kv-gw1-{suffix} | gw1-cert (from s2s-cert1.pfx)    | VPNRootCA2.cer            |
| gw2         | gw2-s2s-kv            | kv-gw2-{suffix} | gw2-cert (from s2s-cert2.pfx)    | VPNRootCA1.cer            |

> [!NOTE]
>
> Each gateway trusts the other gateway's root certificate.
>
> Gateway1 uses the leaf certificates CN=gw1-cer (signed by VPNRootCA1) for its outbound certificate and trusts RootCA2 for inbound connections (and vice versa).
>
> Gateway2 uses the leaf certificates CN=gw2-cer (signed by VPNRootCA2) for its outbound certificate and trusts RootCA1 for inbound connections.

The diagram shows how VPN Gateways, gw1 and gw2, access to the leaf certificates stored in KeyVaults:

[![5]][5]

A network diagram with VPN connections is shown below:

[![6]][6]

The VPN Gateways are configured in active-standby mode; a single VPN conection is established in each VPN Gateway.

### How the scripts orchestrate Key Vault access

The scripts `01_vpn1.ps1` and `02_vpn2.ps1` follow the same pattern to configure secure access:

1. **Create User-Assigned Managed Identity**
   - Each VPN Gateway gets its own managed identity (e.g., `gw1-s2s-kv`, `gw2-s2s-kv`)
   - Created using `New-AzUserAssignedIdentity`

2. **Create Key Vault with RBAC**
   - A dedicated Key Vault is created for each gateway
   - Key Vault names are generated with a unique suffix based on resource group and gateway name

3. **Assign RBAC Roles to Managed Identity**
   - **Key Vault Secrets User** (`4633458b-17de-408a-b874-0445c86b69e6`): Allows get/list secrets
   - **Key Vault Certificate User** (`db79e9a7-68ee-4b58-9aeb-b90e7c24fcba`): Allows get/list certificates

4. **Assign RBAC Role to Current User**
   - **Key Vault Certificates Officer** (`a4417e6f-fecd-4de8-b567-7b0420556985`): Grants full certificate management permissions to import certificates

5. **Import Certificate to Key Vault**
   - The PFX certificate is imported using `Import-AzKeyVaultCertificate`
   - Each gateway imports its respective certificate (`s2s-cert1.pfx` or `s2s-cert2.pfx`)

6. **Associate Managed Identity with VPN Gateway**
   - The VPN Gateway is created with the `-UserAssignedIdentityId` parameter
   - This allows the gateway to authenticate to Key Vault and retrieve its certificate


### References

- [Migration from Access Policy to RBAC](https://learn.microsoft.com/azure/key-vault/general/rbac-migration?tabs=cli)
- [Azure built-in roles for Key Vault data plane operations](https://learn.microsoft.com/azure/key-vault/general/rbac-guide)

`Tag: Site-to-Site VPN, digital certificate authetication` <br>
`date: 22-01-2026`

<!--Image References-->

[1]: ./media/creation-digital-certs.png "Creation of digital certificates"
[2]: ./media/export-digital-certs.png "export digital certificates"
[3]: ./media/network-diagram.png "network diagram"
[4]: ./media/import-digital-certs.png "import leaf certificates in KeyVaults"
[5]: ./media/access-to-digital-certificates.png "VPN Gateway access to the leaf certificates stored in KeyVaults"
[6]: ./media/netwok-diagram-details.png "network diagram with details"

<!--Link References-->

