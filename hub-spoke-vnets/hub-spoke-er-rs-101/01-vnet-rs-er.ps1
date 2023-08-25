################# Input parameters #################
$deploymentName = 'deployment-hubspoke-rs'
$armTemplateFile = '01-vnet-rs-er.json'
$inputParams = 'init.json'
$cloudInitFileName = 'cloud-init.txt'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$parametersFile = "$pathFiles\$inputParams"
$cloudInitFile = "$pathFiles\$cloudInitFileName"

Write-Host "$(Get-Date) - reading file:"$cloudInitFile
If (Test-Path -Path $cloudInitFile) {
    # The command gets the contents of a file as one string, instead of an array of strings. 
    # By default, without the Raw dynamic parameter, content is returned as an array of newline-delimited strings
    $filecontentCloudInit = Get-Content $cloudInitFile -Raw
}
Else { Write-Warning "$(Get-Date) - $cloudInitFile file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

try {
    $arrayParams = (Get-Content -Raw $parametersFile | ConvertFrom-Json)
    $subscriptionName = $arrayParams.subscriptionName
    $resourceGroupName = $arrayParams.resourceGroupName
    $location1 = $arrayParams.location1
    $location2 = $arrayParams.location2
    $adminUsername = $arrayParams.adminUsername
    $adminPassword = $arrayParams.adminPassword
    $erSubscriptionId = $arrayParams.erSubscriptionId
    $erResourceGroup = $arrayParams.erResourceGroup
    $erCircuitName = $arrayParams.erCircuitName
    $erAuthorizationKey = $arrayParams.erAuthorizationKey
  

    # checking the values of variables
    Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
    if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }       else { Write-Host '  subscription name.....: '$subscriptionName -ForegroundColor Yellow }
    if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit }     else { Write-Host '  resource group name...: '$ResourceGroupName -ForegroundColor Yellow }
    if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }             else { Write-Host '  admin username........: '$adminUsername -ForegroundColor Green }
    if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }             else { Write-Host '  admin password........: '$adminPassword -ForegroundColor Green }
    if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }                     else { Write-Host '  location1.............: '$location1 -ForegroundColor Yellow }
    if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }                     else { Write-Host '  location2.............: '$location2 -ForegroundColor Yellow }
    if (!$erSubscriptionId) { Write-Host 'variable erSubscriptionId is null' ; Exit }        else { Write-Host '  erSubscriptionId......: '$erSubscriptionId -ForegroundColor Green }
    if (!$erResourceGroup) { Write-Host 'variable $erResourceGroup is null' ; Exit }         else { Write-Host '  erResourceGroup.......: '$erResourceGroup -ForegroundColor Green }
    if (!$erCircuitName ) { Write-Host 'variable $erCircuitName  is null' ; Exit }           else { Write-Host '  erCircuitName ........: '$erCircuitName -ForegroundColor Green }
    if (!$erAuthorizationKey) { Write-Host 'variable $erAuthorizationKey  is null' ; Exit }  else { Write-Host '  erAuthorizationKey....: '$erAuthorizationKey -ForegroundColor Green }
}
catch {
    Write-Host 'error in reading the template file: '$parametersFile -ForegroundColor Yellow
    Exit
}

$rgName = $ResourceGroupName
$location = $location1

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$parameters = @{
    "location1"        = $location1;
    "location2"        = $location2;
    "erSubscriptionId" = $erSubscriptionId;
    "erResourceGroup"  = $erResourceGroup;
    "erCircuitName"    = $erCircuitName;
    "erAuthorizationKey"= $erAuthorizationKey
}


# Create Resource Group 
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
}
Catch { $rg = New-AzResourceGroup -Name $rgName  -Location $location }


$StartTime = Get-Date
write-host "$StartTime - running ARM template: $templateFile"
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow