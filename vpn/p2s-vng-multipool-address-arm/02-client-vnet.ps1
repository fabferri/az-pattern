################# Input parameters #################
$deploymentName = 'vpn-deployment'
$armTemplateFile = '02-client-vnet.json'
$armTemplateParametersFile = 'init.json'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$parametersFile = "$pathFiles\$armTemplateParametersFile"

try {
    $arrayParams = (Get-Content -Raw $parametersFile | ConvertFrom-Json)
    $subscriptionName = $arrayParams.subscriptionName
    $resourceGroupName = $arrayParams.resourceGroupName
    $location = $arrayParams.location
    $adminUsername = $arrayParams.adminUsername
    $adminPassword = $arrayParams.adminPassword
    $vpnRootCertificateName = $arrayParams.vpnRootCertificateName
    $vpnRootCertificatePublicKey = $arrayParams.vpnRootCertificatePublicKey
    Write-Host "$(Get-Date) - values from file: "$parametersFile -ForegroundColor Yellow
    if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }     else { Write-Host '   subscriptionName......: '$subscriptionName -ForegroundColor Yellow }
    if (!$resourceGroupName) { Write-Host 'variable $resourceGroupName is null' ; Exit }   else { Write-Host '   resourceGroupName.....: '$resourceGroupName -ForegroundColor Yellow }
    if (!$location) { Write-Host 'variable $location is null' ; Exit }                     else { Write-Host '   location..............: '$location -ForegroundColor Yellow }
    if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }           else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green }
    if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }           else { Write-Host '   administrator password: '$adminPassword -ForegroundColor Green }
    if (!$vpnRootCertificateName) { Write-Host 'variable $vpnRootCertificateName is null' ; Exit }           else { Write-Host '   vpnRootCertificateName: '$vpnRootCertificateName -ForegroundColor Green }
    if (!$vpnRootCertificatePublicKey) { Write-Host 'variable $vpnRootCertificatePublicKey is null' ; Exit }           else { Write-Host '   vpnRootCertificatePublicKey: '$vpnRootCertificatePublicKey -ForegroundColor Green }
} 
catch {
    Write-Host 'error in reading the template file: '$parametersFile -ForegroundColor Yellow
    Exit
}

$parameters = @{
    "location"     = $location;
}

# Login Check
Try {
    Write-Host 'Using Subscription: ' -NoNewline
    Write-Host $((Get-AzContext).Name) -ForegroundColor Green
}
Catch {
    Write-Warning 'You are not logged in dummy. Login and try again!'
    Return
}

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group 
Write-Host "$(Get-Date) - Creating Resource Group: $resourceGroupName " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $resourceGroupName  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
}
Catch {
    $rg = New-AzResourceGroup -Name $resourceGroupName  -Location $location
}

$startTime = Get-Date
write-host "$(Get-Date) - ARM template...: "$templateFile
write-host "$(Get-Date) - parameters file: "$parametersFile

New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $resourceGroupName -TemplateFile $templateFile -TemplateParameterObject $parameters  -Verbose 
Write-Host "$(Get-Date) - setup completed" -ForegroundColor Green
$endTime = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host "$(Get-Date) - Script completed" -ForegroundColor Green
Write-Host "Time to complete: "$runTime -ForegroundColor Green