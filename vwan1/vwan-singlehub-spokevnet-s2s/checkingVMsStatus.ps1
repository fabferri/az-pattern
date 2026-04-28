<#
.SYNOPSIS
Returns the power state of all virtual machines in an Azure resource group.

.DESCRIPTION
Queries VMs with instance view and prints a table with VM name, resource group,
location, and normalized power state (for example: running, deallocated).

.PARAMETER ResourceGroupName
Name of the Azure resource group containing the VMs.

.PARAMETER SubscriptionName
Optional Azure subscription name to select before querying VMs.

.EXAMPLE
.\checkingVMsStatus.ps1 -ResourceGroupName spoke22

.EXAMPLE
.\checkingVMsStatus.ps1 -SubscriptionName Hybrid-PM-Test-2 -ResourceGroupName spoke22
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [string]$SubscriptionName
)

$ErrorActionPreference = 'Stop'

# Optional subscription switch when a subscription name is provided.
if ($SubscriptionName) {
    $sub = Get-AzSubscription -SubscriptionName $SubscriptionName
    Select-AzSubscription -SubscriptionId $sub.Id | Out-Null
}

# Retrieve VM instance view to include power state.
$vms = Get-AzVM -ResourceGroupName $ResourceGroupName -Status

$result = foreach ($vm in $vms) {
    # Prefer the direct PowerState returned by PSVirtualMachineListStatus (e.g., "VM running").
    $powerState = 'unknown'
    if ($vm.PowerState) {
        $powerState = ($vm.PowerState -replace '^VM\s+', '').ToLower()
    }
    else {
        $powerStateCode = (
            $vm.Statuses |
            Where-Object { $_.Code -like 'PowerState/*' } |
            Select-Object -First 1
        ).Code

        if ($powerStateCode) {
            $powerState = $powerStateCode.Split('/')[1]
        }
    }

    [PSCustomObject]@{
        ResourceGroup = $ResourceGroupName
        VMName        = $vm.Name
        PowerState    = $powerState
        Location      = $vm.Location
    }
}

$result | Sort-Object VMName | Format-Table -AutoSize
