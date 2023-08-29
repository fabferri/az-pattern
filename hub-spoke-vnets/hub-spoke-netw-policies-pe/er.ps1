################# Input parameters #################
$deploymentName = 'test-pe'
$armTemplateFile = 'er.json'
$inputParams = 'init.json'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$parametersFile = "$pathFiles\$inputParams"

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
} 
catch {
  Write-Host 'error in reading the input parameters file: '$parametersFile -ForegroundColor Yellow
  Exit
}


# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }             else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }             else { Write-Host '   administrator password: '$adminPassword -ForegroundColor Green }
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }       else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit }     else { Write-Host '   resource group name...: '$ResourceGroupName -ForegroundColor Yellow }
if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }                     else { Write-Host '   vnet1 location........: '$location1 -ForegroundColor Yellow }
if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }                     else { Write-Host '   vnet2 location........: '$location2 -ForegroundColor Yellow }
if (!$erSubscriptionId) { Write-Host 'variable $erSubscriptionId is null' ; Exit }       else { Write-Host '   erSubscriptionId......: '$erSubscriptionId -ForegroundColor Yellow }
if (!$erResourceGroup) { Write-Host 'variable $erResourceGroup is null' ; Exit }         else { Write-Host '   erResourceGroup.......: '$erResourceGroup -ForegroundColor Yellow }
if (!$erCircuitName) { Write-Host 'variable $erCircuitName is null' ; Exit }             else { Write-Host '   erCircuitName.........: '$erCircuitName -ForegroundColor Yellow }
if (!$erAuthorizationKey) { Write-Host 'variable $erAuthorizationKey is null' ; Exit }   else { Write-Host '   erAuthorizationKey....: '$erAuthorizationKey -ForegroundColor Yellow }

$rgName = $ResourceGroupName

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Login Check
Try {
  Write-Host 'Using Subscription: ' -NoNewline
  Write-Host $((Get-AzContext).Name) -ForegroundColor Green
}
Catch {
  Write-Warning 'You are not logged in dummy. Login and try again!'
  Return
}

$parameters = @{
  "location1"          = $location1;
  "location2"          = $location2;
  "adminUsername"      = $adminUsername;
  "adminPassword"      = $adminPassword;
  "erSubscriptionId"   = $erSubscriptionId;
  "erResourceGroup"    = $erResourceGroup;
  "erCircuitName"      = $erCircuitName;
  "erAuthorizationKey" = $erAuthorizationKey
}


$location = $location1        
# Create Resource Group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Resource Group' -ForegroundColor Cyan
Try {
  Get-AzResourceGroup -Name $rgName -ErrorAction Stop
  Write-Host 'Resource exists, skipping'
}
Catch { New-AzResourceGroup -Name $rgName -Location $location }



$startTime = "$(Get-Date)"
$runTime = Measure-Command {
  write-host "running ARM template:"$templateFile
  New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}
 
write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "endt time.: "$(Get-Date) -ForegroundColor Yellow