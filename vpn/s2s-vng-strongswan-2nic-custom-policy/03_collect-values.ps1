################# Input parameters #################
$armTemplateParametersFile = 'init.json'
$bashScript = 'configure-nva.sh'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$parametersFile = "$pathFiles\$armTemplateParametersFile"
$bashScriptPath = "$pathFiles\$bashScript"

# Read parameters from init.json
try {
    $arrayParams = (Get-Content -Raw $parametersFile | ConvertFrom-Json)
    $subscriptionName = $arrayParams.subscriptionName
    $resourceGroupName = $arrayParams.resourceGroupName
    $gatewayName = $arrayParams.gatewayName
    $nvaName = $arrayParams.nvaName

    Write-Host "$(Get-Date) - values from file: $parametersFile" -ForegroundColor Yellow
    if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }
    if (!$resourceGroupName) { Write-Host 'variable $resourceGroupName is null' ; Exit }
    if (!$gatewayName) { Write-Host 'variable $gatewayName is null' ; Exit }
    if (!$nvaName) { Write-Host 'variable $nvaName is null' ; Exit }

    Write-Host "   subscriptionName......: $subscriptionName" -ForegroundColor Yellow
    Write-Host "   resourceGroupName.....: $resourceGroupName" -ForegroundColor Yellow
    Write-Host "   gatewayName...........: $gatewayName" -ForegroundColor Cyan
    Write-Host "   nvaName...............: $nvaName" -ForegroundColor Cyan
}
catch {
    Write-Host "Error reading parameters file: $parametersFile" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    Exit
}

# Login check
try {
    $account = az account show 2>&1 | ConvertFrom-Json
    if (-not $account.id) { throw 'not logged in' }
    Write-Host "Using Account: $($account.user.name)" -ForegroundColor Green
}
catch {
    Write-Warning 'You are not logged in. Run "az login" and try again!'
    Return
}

# Set subscription
try {
    az account set --subscription $subscriptionName
    if ($LASTEXITCODE -ne 0) { throw "Failed to set subscription: $subscriptionName" }
}
catch {
    Write-Host "Error setting subscription: $_" -ForegroundColor Red
    Exit
}

# Derive resource names from ARM template naming conventions
$gwPubIP1Name = "$gatewayName-pubIP1"
$gwPubIP2Name = "$gatewayName-pubIP2"
$nvaPubIPName = "$nvaName-pubIP"
$nvaNicExternalName = "$nvaName-nic-external"
$nvaNicInternalName = "$nvaName-nic-internal"
$connectionName1 = "conn1-to-nva"
$connectionName2 = "conn2-to-nva"

Write-Host ""
Write-Host "=== Collecting values from Azure ===" -ForegroundColor Cyan

###############################################################################
# 1. VPN Gateway public IPs
###############################################################################
try {
    Write-Host "  Querying VPN Gateway public IP 1: $gwPubIP1Name" -ForegroundColor Gray
    $vpngwPip0 = az network public-ip show `
        --resource-group $resourceGroupName `
        --name $gwPubIP1Name `
        --query ipAddress --output tsv
    if ($LASTEXITCODE -ne 0 -or !$vpngwPip0) { throw "Failed to get public IP: $gwPubIP1Name" }

    Write-Host "  Querying VPN Gateway public IP 2: $gwPubIP2Name" -ForegroundColor Gray
    $vpngwPip1 = az network public-ip show `
        --resource-group $resourceGroupName `
        --name $gwPubIP2Name `
        --query ipAddress --output tsv
    if ($LASTEXITCODE -ne 0 -or !$vpngwPip1) { throw "Failed to get public IP: $gwPubIP2Name" }
}
catch {
    Write-Host "Error querying VPN Gateway public IPs: $_" -ForegroundColor Red
    Exit
}

###############################################################################
# 2. VPN Gateway BGP settings
###############################################################################
try {
    Write-Host "  Querying VPN Gateway BGP settings: $gatewayName" -ForegroundColor Gray
    $gwJson = az network vnet-gateway show `
        --resource-group $resourceGroupName `
        --name $gatewayName `
        --query "bgpSettings" --output json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or !$gwJson) { throw "Failed to get VPN Gateway BGP settings" }

    $vpngwBgpAsn = $gwJson.asn

    # For active-active, use bgpPeeringAddresses array (reliable for all API versions)
    if ($gwJson.bgpPeeringAddresses -and $gwJson.bgpPeeringAddresses.Count -ge 2) {
        $vpngwBgpIp0 = $gwJson.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]
        $vpngwBgpIp1 = $gwJson.bgpPeeringAddresses[1].defaultBgpIpAddresses[0]
    }
    else {
        # Fallback: bgpPeeringAddress as comma-separated string
        $bgpIPs = $gwJson.bgpPeeringAddress -split ','
        $vpngwBgpIp0 = $bgpIPs[0].Trim()
        $vpngwBgpIp1 = $bgpIPs[1].Trim()
    }

    if (!$vpngwBgpIp0 -or !$vpngwBgpIp1) { throw "Failed to parse both BGP IPs from gateway" }
}
catch {
    Write-Host "Error querying VPN Gateway BGP settings: $_" -ForegroundColor Red
    Exit
}

###############################################################################
# 3. NVA public IP (external NIC: SSH + IPsec endpoint)
###############################################################################
try {
    Write-Host "  Querying NVA public IP: $nvaPubIPName" -ForegroundColor Gray
    $nvaPubIP = az network public-ip show `
        --resource-group $resourceGroupName `
        --name $nvaPubIPName `
        --query ipAddress --output tsv
    if ($LASTEXITCODE -ne 0 -or !$nvaPubIP) { throw "Failed to get public IP: $nvaPubIPName" }
}
catch {
    Write-Host "Error querying NVA public IP: $_" -ForegroundColor Red
    Exit
}

###############################################################################
# 4. NVA private IPs (external + internal NICs)
###############################################################################
try {
    Write-Host "  Querying NVA external NIC private IP: $nvaNicExternalName" -ForegroundColor Gray
    $nvaExternalPrivIP = az network nic show `
        --resource-group $resourceGroupName `
        --name $nvaNicExternalName `
        --query "ipConfigurations[0].privateIPAddress" --output tsv
    if ($LASTEXITCODE -ne 0 -or !$nvaExternalPrivIP) { throw "Failed to get NIC private IP: $nvaNicExternalName" }

    Write-Host "  Querying NVA internal NIC private IP: $nvaNicInternalName" -ForegroundColor Gray
    $nvaInternalPrivIP = az network nic show `
        --resource-group $resourceGroupName `
        --name $nvaNicInternalName `
        --query "ipConfigurations[0].privateIPAddress" --output tsv
    if ($LASTEXITCODE -ne 0 -or !$nvaInternalPrivIP) { throw "Failed to get NIC private IP: $nvaNicInternalName" }
}
catch {
    Write-Host "Error querying NVA NIC: $_" -ForegroundColor Red
    Exit
}

###############################################################################
# 5. VPN connection shared keys
###############################################################################
try {
    Write-Host "  Querying VPN connection shared key: $connectionName1" -ForegroundColor Gray
    $vpnPsk1 = az network vpn-connection shared-key show `
        --resource-group $resourceGroupName `
        --connection-name $connectionName1 `
        --query value --output tsv
    if ($LASTEXITCODE -ne 0 -or !$vpnPsk1) { throw "Failed to get shared key for: $connectionName1" }

    Write-Host "  Querying VPN connection shared key: $connectionName2" -ForegroundColor Gray
    $vpnPsk2 = az network vpn-connection shared-key show `
        --resource-group $resourceGroupName `
        --connection-name $connectionName2 `
        --query value --output tsv
    if ($LASTEXITCODE -ne 0 -or !$vpnPsk2) { throw "Failed to get shared key for: $connectionName2" }

    # Use the same PSK for configure-nva.sh (both connections must share the same key
    # since strongSwan uses a single PSK for both tunnels)
    if ($vpnPsk1 -ne $vpnPsk2) {
        Write-Warning "Shared keys differ between connections! conn1='$vpnPsk1' conn2='$vpnPsk2'"
        Write-Warning "Using conn1 key. Ensure both connections use the same PSK for strongSwan."
    }
    $vpnPsk = $vpnPsk1
}
catch {
    Write-Host "Error querying VPN shared key: $_" -ForegroundColor Red
    Exit
}

###############################################################################
# 6. NVA SSH IP (external NIC public IP in dual-NIC design)
###############################################################################
$nvaMngPubIP = $nvaPubIP

###############################################################################
# Display collected values
###############################################################################
Write-Host ""
Write-Host "=== Collected Values ===" -ForegroundColor Green
Write-Host "  VPNGW_PIP0.............: $vpngwPip0" -ForegroundColor Yellow
Write-Host "  VPNGW_PIP1.............: $vpngwPip1" -ForegroundColor Yellow
Write-Host "  VPNGW_BGP_IP0..........: $vpngwBgpIp0" -ForegroundColor Yellow
Write-Host "  VPNGW_BGP_IP1..........: $vpngwBgpIp1" -ForegroundColor Yellow
Write-Host "  VPNGW_BGP_ASN..........: $vpngwBgpAsn" -ForegroundColor Yellow
Write-Host "  NVA_PUBLIC_IP..........: $nvaPubIP" -ForegroundColor Yellow
Write-Host "  NVA_EXTERNAL_IP........: $nvaExternalPrivIP" -ForegroundColor Yellow
Write-Host "  NVA_INTERNAL_IP........: $nvaInternalPrivIP" -ForegroundColor Yellow
Write-Host "  VPN_PSK (conn1)........: $vpnPsk1" -ForegroundColor Yellow
Write-Host "  VPN_PSK (conn2)........: $vpnPsk2" -ForegroundColor Yellow
Write-Host "  NVA SSH IP.............: $nvaMngPubIP" -ForegroundColor Cyan
Write-Host ""

###############################################################################
# Update configure-nva.sh with collected values
###############################################################################
Write-Host "=== Updating $bashScript ===" -ForegroundColor Cyan

try {
    if (-not (Test-Path $bashScriptPath)) { throw "File not found: $bashScriptPath" }

    $content = Get-Content -Raw $bashScriptPath

    # Replace each variable value using regex pattern matching the exact variable assignment
    $replacements = @(
        @{ Pattern = '(NVA_EXTERNAL_IP=)"[^"]*"';          Value = "`${1}`"$nvaExternalPrivIP`"" }
        @{ Pattern = '(NVA_PUBLIC_IP=)"[^"]*"';            Value = "`${1}`"$nvaPubIP`"" }
        @{ Pattern = '(VPNGW_PIP0=)"[^"]*"';               Value = "`${1}`"$vpngwPip0`"" }
        @{ Pattern = '(VPNGW_PIP1=)"[^"]*"';               Value = "`${1}`"$vpngwPip1`"" }
        @{ Pattern = '(VPNGW_BGP_IP0=)"[^"]*"';            Value = "`${1}`"$vpngwBgpIp0`"" }
        @{ Pattern = '(VPNGW_BGP_IP1=)"[^"]*"';            Value = "`${1}`"$vpngwBgpIp1`"" }
        @{ Pattern = '(VPNGW_BGP_ASN=)\d+';                Value = "`${1}$vpngwBgpAsn" }
        @{ Pattern = '(VPN_PSK=)"[^"]*"';                  Value = "`${1}`"$vpnPsk`"" }
    )

    foreach ($r in $replacements) {
        if ($content -notmatch $r.Pattern) {
            Write-Warning "Pattern not found in script: $($r.Pattern)"
        }
        $content = $content -replace $r.Pattern, $r.Value
    }

    # Write back with Unix line endings (LF)
    $content = $content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($bashScriptPath, $content, [System.Text.UTF8Encoding]::new($false))

    Write-Host "  $bashScript updated successfully" -ForegroundColor Green
}
catch {
    Write-Host "Error updating $bashScript`: $_" -ForegroundColor Red
    Exit
}

###############################################################################
# Summary
###############################################################################
Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "  configure-nva.sh has been updated with live Azure values."
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Cyan
Write-Host "    1. Copy the script to the NVA:"
Write-Host "       scp $bashScriptPath ${($arrayParams.adminUsername)}@${nvaMngPubIP}:~/" -ForegroundColor White
Write-Host "    2. SSH to the NVA and run it:"
Write-Host "       ssh ${($arrayParams.adminUsername)}@${nvaMngPubIP}" -ForegroundColor White
Write-Host "       sudo bash ~/configure-nva.sh" -ForegroundColor White
Write-Host ""
