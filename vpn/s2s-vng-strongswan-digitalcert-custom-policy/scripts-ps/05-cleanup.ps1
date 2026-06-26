#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Tears down all Azure resources created by 02-deploy-azure.ps1.

.DESCRIPTION
    Reads init.json for subscription and resource group name, prompts for
    confirmation, then deletes the entire resource group as a background job
    (VPN Gateway, VNets, Public IPs, Key Vaults, Managed Identities, NSGs,
    Local Network Gateways, VPN Connections, and any test VMs).
    Also prints guidance for removing local certificate files from ./certs/.

.NOTES
    Prerequisites:
      - Az PowerShell modules installed and logged in
      - init.json present in the repository root with subscriptionName and rgName
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
$rgName = $params.rgName

Write-Host ">>> Cleanup: Deleting resource group '$rgName'"
Write-Host "  Subscription: $subscriptionName"
Write-Host ""

$confirm = Read-Host "Are you sure you want to delete ALL resources in '$rgName'? (y/N)"
if ($confirm -notin @('y', 'Y')) {
    Write-Host "Aborted."
    exit 0
}

Set-AzContext -Subscription $subscriptionName | Out-Null

Write-Host ">>> Deleting resource group: $rgName (this may take several minutes)"
$rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
if ($rg) {
    Remove-AzResourceGroup -Name $rgName -Force -AsJob | Out-Null
    Write-Host "  Resource group deletion initiated (running in background)"
} else {
    Write-Host "  Resource group not found: $rgName"
}

Write-Host ""
Write-Host "==========================================="
Write-Host "  Cleanup initiated"
Write-Host "==========================================="
Write-Host ""
Write-Host "Monitor deletion: Get-AzResourceGroup -Name $rgName | Select-Object ProvisioningState"
Write-Host ""
Write-Host "To also remove local certificates:"
Write-Host "  Remove-Item -Recurse -Force (Join-Path '$pathFiles' 'certs')"
