#
# Collects and displays all Azure Policy definitions and assignments
# created by 05-avnm-manager.json for AVNM dynamic network group membership.
#
# The policies are custom, subscription-scoped, with display names matching
# "AVNM dynamic membership*" and mode "Microsoft.Network.Data".
#
# Variables in init.json:
#   $subscriptionName : Azure subscription name
#   $ResourceGroupName: resource group (used to reconstruct expected network group IDs)
#
################# Input parameters #################
$initFile = 'init.json'
####################################################

$pathFiles       = Split-Path -Parent $PSCommandPath
$inputParamsFile = if ([System.IO.Path]::IsPathRooted($initFile)) {
    $initFile
} else {
    Join-Path $pathFiles $initFile
}

if (-not (Test-Path -Path $inputParamsFile -PathType Leaf)) {
    Write-Host "parameters file not found: $inputParamsFile" -ForegroundColor Yellow
    Exit 1
}

try {
    $arrayParams       = Get-Content -Raw $inputParamsFile | ConvertFrom-Json
    $subscriptionName  = $arrayParams.subscriptionName
    $ResourceGroupName = $arrayParams.ResourceGroupName
}
catch {
    Write-Host "error reading parameters file: $inputParamsFile" -ForegroundColor Yellow
    Exit 1
}

if (!$subscriptionName)  { Write-Host 'variable $subscriptionName is null'  ; Exit }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit }

Write-Host "$(Get-Date) - subscription...: $subscriptionName"  -ForegroundColor Yellow
Write-Host "$(Get-Date) - resource group.: $ResourceGroupName" -ForegroundColor Yellow

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

Try {
    Write-Host 'Using Subscription: ' -NoNewline
    Write-Host $((Get-AzContext).Name) -ForegroundColor Green
}
Catch {
    Write-Warning 'You are not logged in. Login and try again!'
    Return
}

$subscriptionId = $subscr.Id

# -----------------------------------------------------------------------
# 1. Collect policy definitions scoped to this subscription
#    NOTE: In current Az module versions top-level properties (DisplayName,
#    Mode, PolicyType) are exposed directly on the object, not under .Properties
# -----------------------------------------------------------------------
Write-Host "`n$(Get-Date) - querying policy definitions (Mode=Microsoft.Network.Data, subscription scope)..." -ForegroundColor Cyan

$allDefs = Get-AzPolicyDefinition -SubscriptionId $subscriptionId -Custom

$policyDefs = $allDefs | Where-Object {
    $_.Mode -eq 'Microsoft.Network.Data' -and
    $_.PolicyType -eq 'Custom' -and
    $_.Id -like "*/subscriptions/$subscriptionId/*"
}

if (-not $policyDefs) {
    Write-Host "No AVNM dynamic membership policy definitions found at subscription scope." -ForegroundColor Yellow
    Write-Host "  (total custom Microsoft.Network.Data definitions visible: $(($allDefs | Where-Object { $_.Mode -eq 'Microsoft.Network.Data' }).Count))" -ForegroundColor Gray
} else {
    Write-Host "`n--- Policy Definitions ($(@($policyDefs).Count) found) ---" -ForegroundColor Green
    foreach ($def in @($policyDefs)) {
        Write-Host ""
        Write-Host "  Name        : $($def.Name)"        -ForegroundColor White
        Write-Host "  DisplayName : $($def.DisplayName)" -ForegroundColor White
        Write-Host "  Description : $($def.Description)" -ForegroundColor White
        Write-Host "  Mode        : $($def.Mode)"        -ForegroundColor White
        Write-Host "  PolicyType  : $($def.PolicyType)"  -ForegroundColor White
        Write-Host "  ResourceId  : $($def.Id)"          -ForegroundColor White
        # extract the target network group ID and tag filter from the policy rule
        try {
            $ngId         = $def.PolicyRule.then.details.networkGroupId
            $tagCondition = $def.PolicyRule.if.allOf | Where-Object { $_.field -like "tags*" }
            if ($ngId)         { Write-Host "  NetworkGroup: $ngId"                                            -ForegroundColor Cyan }
            if ($tagCondition) { Write-Host "  Tag filter  : $($tagCondition.field) = $($tagCondition.equals)" -ForegroundColor Cyan }
        } catch {}
    }
}

# -----------------------------------------------------------------------
# 2. Collect policy assignments at subscription scope
# -----------------------------------------------------------------------
Write-Host "`n$(Get-Date) - querying policy assignments (subscription scope)..." -ForegroundColor Cyan

$allAsgns = Get-AzPolicyAssignment -Scope "/subscriptions/$subscriptionId"

$policyAssignments = $allAsgns | Where-Object {
    $_.DisplayName -like 'AVNM dynamic membership*'
}

if (-not $policyAssignments) {
    Write-Host "No AVNM dynamic membership policy assignments found." -ForegroundColor Yellow
    Write-Host "  (total assignments at subscription scope: $(@($allAsgns).Count))" -ForegroundColor Gray
} else {
    Write-Host "`n--- Policy Assignments ($(@($policyAssignments).Count) found) ---" -ForegroundColor Green
    foreach ($asgn in @($policyAssignments)) {
        Write-Host ""
        Write-Host "  Name              : $($asgn.Name)"              -ForegroundColor White
        Write-Host "  DisplayName       : $($asgn.DisplayName)"       -ForegroundColor White
        Write-Host "  EnforcementMode   : $($asgn.EnforcementMode)"   -ForegroundColor White
        Write-Host "  PolicyDefinitionId: $($asgn.PolicyDefinitionId)" -ForegroundColor White
        Write-Host "  ResourceId        : $($asgn.Id)"                -ForegroundColor White
    }
}

# -----------------------------------------------------------------------
# 3. Cross-reference: show def -> assignment mapping
# -----------------------------------------------------------------------
if ($policyDefs -and $policyAssignments) {
    Write-Host "`n--- Cross-reference: Definition -> Assignment ---" -ForegroundColor Cyan
    foreach ($def in @($policyDefs)) {
        $matchingAsgn = @($policyAssignments) | Where-Object { $_.PolicyDefinitionId -eq $def.Id }
        Write-Host "  $($def.DisplayName)" -ForegroundColor White
        Write-Host "    DefId  : $($def.Id)"                 -ForegroundColor Gray
        Write-Host "    AsgnId : $(if ($matchingAsgn) { $matchingAsgn.Id } else { '(no assignment found)' })" -ForegroundColor Gray
    }
}

Write-Host "`n$(Get-Date) - done." -ForegroundColor Green
