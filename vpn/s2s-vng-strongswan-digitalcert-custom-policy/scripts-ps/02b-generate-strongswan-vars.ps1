#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Network
<#
.SYNOPSIS
    Collects every value needed by 03-configure-strongswan.ps1 and writes them
    into the Variables block of that script in place.

.DESCRIPTION
    Auto-populates the variable assignments at the top of 03-configure-strongswan.ps1
    so it can be run without manual editing. The workflow is:

      1. Reads static parameters from init.json (ASN, address spaces, cert names,
         XFRM if_id values, NVA private IP, etc.).
      2. Computes derived values (NVA subnet default gateway).
      3. Queries Azure live for dynamic values: NVA public IP, VPN Gateway public
         IPs (active-active), and VPN Gateway BGP peering addresses.
      4. Creates a timestamped backup of 03-configure-strongswan.ps1.
      5. Uses regex replacement to patch each $VARIABLE = "..." line in the target
         script with the resolved values.

    After running this script, 03-configure-strongswan.ps1 is ready to execute
    with no further edits required.

.NOTES
    Prerequisites:
      - Az PowerShell modules installed
      - Logged in (Connect-AzAccount)
      - 02-deploy-azure.ps1 already run (VPN Gateway + NVA exist)

    A timestamped backup of 03-configure-strongswan.ps1 is created before editing.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Log { param([string]$Message) Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" }

###############################################################################
# Paths
###############################################################################
$scriptDir = $PSScriptRoot
$pathFiles = Split-Path -Parent $scriptDir
$inputParamsFile = Join-Path $pathFiles 'init.json'
$targetScript = Join-Path $scriptDir '03-configure-strongswan.ps1'

foreach ($f in @($inputParamsFile, $targetScript)) {
    if (-not (Test-Path $f)) {
        Write-Error "File not found: $f"
        exit 1
    }
}

###############################################################################
# 1. Read static values from init.json
###############################################################################
Log "- Reading static values from init.json"
$params = Get-Content $inputParamsFile -Raw | ConvertFrom-Json

$subscriptionName    = $params.subscriptionName
$rgName              = $params.rgName
$gwName              = $params.gwName
$gwAsn               = $params.gwAsn
$vnetAddress         = $params.vnetAddress
$nvaVmName           = $params.nvaVmName
$nvaPrivateIp        = $params.nvaPrivateIp
$nvaSubnetAddress    = $params.nvaSubnetAddress
$nvaAppSubnetAddress = $params.nvaAppSubnetAddress
$nvaAsn              = $params.nvaAsn
$nvaBgpIp0           = $params.nvaBgpIp0
$nvaBgpIp1           = $params.nvaBgpIp1
$xfrmIfId0           = $params.xfrmIfId0
$xfrmIfId1           = $params.xfrmIfId1
$advertiseNetwork    = $params.advertiseNetwork
$enableSnat          = $params.enableSnat
$certRootSubjectGw   = $params.certRootSubjectGw
$certRootSubjectSwan = $params.certRootSubjectSwan
$certLeafSubjectGw   = $params.certLeafSubjectGw
$certLeafSubjectSwan = $params.certLeafSubjectSwan

# Derived names (must match 02-deploy-azure.ps1)
$gwPubIp1Name = "${gwName}pip1"
$gwPubIp2Name = "${gwName}pip2"
$nvaPubIpName = "${nvaVmName}-pip"

# Default gateway of the NVA subnet = network address + 1
$subnetParts = ($nvaSubnetAddress -split '/')[0] -split '\.'
$nvaGw = "$($subnetParts[0]).$($subnetParts[1]).$($subnetParts[2]).$([int]$subnetParts[3] + 1)"

###############################################################################
# 2. Query dynamic values from Azure
###############################################################################
Log "- Setting subscription: $subscriptionName"
Set-AzContext -Subscription $subscriptionName | Out-Null

Log "- Querying NVA public IP: $nvaPubIpName"
$nvaPubIp = (Get-AzPublicIpAddress -ResourceGroupName $rgName -Name $nvaPubIpName).IpAddress

Log "- Querying VPN Gateway public IPs"
$gwPubIp1 = (Get-AzPublicIpAddress -ResourceGroupName $rgName -Name $gwPubIp1Name).IpAddress
$gwPubIp2 = (Get-AzPublicIpAddress -ResourceGroupName $rgName -Name $gwPubIp2Name).IpAddress

Log "- Querying VPN Gateway BGP peering IPs"
$gw = Get-AzVirtualNetworkGateway -ResourceGroupName $rgName -Name $gwName
$gwBgpIp0 = $gw.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses[0]
$gwBgpIp1 = $gw.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses[0]

# Validate dynamic values
$validationPairs = @{
    'NVA_PUBLIC_IP' = $nvaPubIp
    'VPNGW_PIP0'    = $gwPubIp1
    'VPNGW_PIP1'    = $gwPubIp2
    'VPNGW_BGP_IP0' = $gwBgpIp0
    'VPNGW_BGP_IP1' = $gwBgpIp1
}
foreach ($pair in $validationPairs.GetEnumerator()) {
    if ([string]::IsNullOrEmpty($pair.Value)) {
        Write-Error "Could not resolve $($pair.Key) from Azure. Is 02-deploy-azure.ps1 complete?"
        exit 1
    }
}

###############################################################################
# 3. Write values into 03-configure-strongswan.ps1
###############################################################################
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = "${targetScript}.${timestamp}.bak"
Copy-Item -Path $targetScript -Destination $backupPath
Log "- Backup created: $(Split-Path -Leaf $backupPath)"

$content = Get-Content $targetScript -Raw

# set_var: Replace variable assignments in the target script
function Set-ScriptVar {
    param([string]$VarName, [string]$Value)

    # Match: $VarName = "value" or $VarName = value (with optional inline comment)
    $pattern = "(?m)^(\`$$VarName\s*=\s*)(`"[^`"]*`"|'[^']*'|[^\s#]*)(\s*#.*)?\s*$"

    # Determine if value should be quoted or not
    if ($Value -match '^\d+$') {
        $replacement = "`${1}$Value`${3}"
    } else {
        $replacement = "`${1}`"$Value`"`${3}"
    }

    $script:content = [regex]::Replace($script:content, $pattern, $replacement)
    Log "    $VarName = $Value"
}

Log "- Updating variables in 03-configure-strongswan.ps1"
Set-ScriptVar 'NVA_PRIVATE_IP'    $nvaPrivateIp
Set-ScriptVar 'NVA_PUBLIC_IP'     $nvaPubIp
Set-ScriptVar 'NVA_GW'            $nvaGw
Set-ScriptVar 'NVA_BGP_ASN'       "$nvaAsn"
Set-ScriptVar 'NVA_BGP_IP0'       $nvaBgpIp0
Set-ScriptVar 'NVA_BGP_IP1'       $nvaBgpIp1
Set-ScriptVar 'VPNGW_PIP0'        $gwPubIp1
Set-ScriptVar 'VPNGW_PIP1'        $gwPubIp2
Set-ScriptVar 'VPNGW_BGP_IP0'     $gwBgpIp0
Set-ScriptVar 'VPNGW_BGP_IP1'     $gwBgpIp1
Set-ScriptVar 'VPNGW_BGP_ASN'     "$gwAsn"
Set-ScriptVar 'XFRM_IF_ID0'       "$xfrmIfId0"
Set-ScriptVar 'XFRM_IF_ID1'       "$xfrmIfId1"
Set-ScriptVar 'ADVERTISE_NETWORK' $advertiseNetwork
Set-ScriptVar 'SUBNET_APP'        $nvaAppSubnetAddress
Set-ScriptVar 'ENABLE_SNAT'       $enableSnat
Set-ScriptVar 'REMOTE_NETWORK'    $vnetAddress
Set-ScriptVar 'CERT_LEAF_NAME'    $certLeafSubjectSwan
Set-ScriptVar 'CERT_LEAF_GW'      $certLeafSubjectGw
Set-ScriptVar 'CERT_ROOT_GW'      $certRootSubjectGw
Set-ScriptVar 'CERT_ROOT_SWAN'    $certRootSubjectSwan

Set-Content -Path $targetScript -Value $content -NoNewline -Encoding UTF8

###############################################################################
# Summary
###############################################################################
Log " "
Log "==========================================="
Log "  03-configure-strongswan.ps1 variables set"
Log "==========================================="
Log "  NVA public IP:        $nvaPubIp"
Log "  NVA private IP:       $nvaPrivateIp"
Log "  NVA default gateway:  $nvaGw"
Log "  VPN GW public IP 0:   $gwPubIp1 (BGP: $gwBgpIp0)"
Log "  VPN GW public IP 1:   $gwPubIp2 (BGP: $gwBgpIp1)"
Log " "
Log "Next step: Run 03-configure-strongswan.ps1 to configure the NVA remotely."
