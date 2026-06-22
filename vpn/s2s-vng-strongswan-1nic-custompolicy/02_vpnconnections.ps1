################# Input parameters #################
$deploymentName = 'gw-conn'
$armTemplateFile = '02_vpnconnections.json'
$armTemplateParametersFile = 'init.json'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$parametersFile = "$pathFiles\$armTemplateParametersFile"

# Read parameters from init.json
try {
    $arrayParams = (Get-Content -Raw $parametersFile | ConvertFrom-Json)
    $subscriptionName = $arrayParams.subscriptionName
    $resourceGroupName = $arrayParams.resourceGroupName
    $location = $arrayParams.location
    $location1 = $arrayParams.location1
    $location2 = $arrayParams.location2
    $gatewayName = $arrayParams.gatewayName
    $nvaName = $arrayParams.nvaName
    $adminUsername = $arrayParams.adminUsername
    $adminPassword = $arrayParams.adminPassword

    Write-Host "$(Get-Date) - values from file: $parametersFile" -ForegroundColor Yellow
    if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host "   subscriptionName......: $subscriptionName" -ForegroundColor Yellow }
    if (!$resourceGroupName) { Write-Host 'variable $resourceGroupName is null' ; Exit } else { Write-Host "   resourceGroupName.....: $resourceGroupName" -ForegroundColor Yellow }
    if (!$location) { Write-Host 'variable $location is null' ; Exit }                   else { Write-Host "   location..............: $location" -ForegroundColor Yellow }
    if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }                 else { Write-Host "   location1.............: $location1" -ForegroundColor Yellow }
    if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }                 else { Write-Host "   location2.............: $location2" -ForegroundColor Yellow }
    if (!$gatewayName) { Write-Host 'variable $gatewayName is null' ; Exit }             else { Write-Host "   gatewayName...........: $gatewayName" -ForegroundColor Cyan }
    if (!$nvaName) { Write-Host 'variable $nvaName is null' ; Exit }                     else { Write-Host "   nvaName...............: $nvaName" -ForegroundColor Cyan }
    if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }          else { Write-Host "   administrator username: $adminUsername" -ForegroundColor Green }
    if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host "   administrator password: *****" -ForegroundColor Green }
}
catch {
    Write-Host "error in reading the parameters file: $parametersFile" -ForegroundColor Red
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
    Write-Host "$(Get-Date) - Setting subscription: $subscriptionName" -ForegroundColor Cyan
    az account set --subscription $subscriptionName
    if ($LASTEXITCODE -ne 0) { throw "Failed to set subscription: $subscriptionName" }
}
catch {
    Write-Host "Error setting subscription: $_" -ForegroundColor Red
    Exit
}

# Create Resource Group
Write-Host "$(Get-Date) - Creating Resource Group: $resourceGroupName" -ForegroundColor Cyan
try {
    $rgExists = az group exists --name $resourceGroupName
    if ($rgExists -eq 'true') {
        Write-Host '  resource group exists, skipping'
    }
    else {
        az group create --name $resourceGroupName --location $location --output none
        if ($LASTEXITCODE -ne 0) { throw "Failed to create resource group: $resourceGroupName" }
        Write-Host "  resource group created" -ForegroundColor Green
    }
}
catch {
    Write-Host "Error creating resource group: $_" -ForegroundColor Red
    Exit
}

# Deploy ARM template
$startTime = Get-Date
Write-Host "$(Get-Date) - ARM template...: $templateFile"
Write-Host "$(Get-Date) - parameters file: $parametersFile"

try {
    $paramObj = @{
        "`$schema" = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
        contentVersion = "1.0.0.0"
        parameters = @{
            location1   = @{ value = $location1 }
            location2   = @{ value = $location2 }
            gatewayName = @{ value = $gatewayName }
            nvaName     = @{ value = $nvaName }
        }
    }
    $paramTempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "deploy-params-$deploymentName.json")
    $paramObj | ConvertTo-Json -Depth 4 | Set-Content -Path $paramTempFile -Encoding utf8

    $result = az deployment group create `
        --name $deploymentName `
        --resource-group $resourceGroupName `
        --template-file $templateFile `
        --parameters "@$paramTempFile" `
        --verbose 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Deployment failed: $result"
    }

    $deployment = $result | Where-Object { $_ -notmatch '^(VERBOSE|WARNING|INFO|ERROR):' } | Out-String | ConvertFrom-Json

    Write-Host "$(Get-Date) - Deployment completed successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== Deployment Outputs ===" -ForegroundColor Cyan
    if ($deployment.properties.outputs) {
        $outputs = $deployment.properties.outputs
        foreach ($key in $outputs.PSObject.Properties.Name) {
            Write-Host "  $($key): $($outputs.$key.value)" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "Deployment error: $_" -ForegroundColor Red
    Exit
}
finally {
    if (Test-Path $paramTempFile) { Remove-Item $paramTempFile -Force }
}

$endTime = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host "$(Get-Date) - Script completed" -ForegroundColor Green
Write-Host "Time to complete: $runTime" -ForegroundColor Green
