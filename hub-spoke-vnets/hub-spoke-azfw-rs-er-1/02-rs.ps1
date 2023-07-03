################# Input parameters #################
$deploymentName = 'er-and-rs'
$armTemplateFile = '02-rs.json'
$inputParams = 'init.json'
$cloudInitFileNameNVA1 = 'cloud-init-nva1.txt'
$cloudInitFileNameNVA2 = 'cloud-init-nva2.txt'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$parametersFile = "$pathFiles\$inputParams"
$cloudInitFileNVA1 = "$pathFiles\$cloudInitFileNameNVA1"
$cloudInitFileNVA2 = "$pathFiles\$cloudInitFileNameNVA2"

Write-Host "$(Get-Date) - reading file:"$cloudInitFileNVA1
If (Test-Path -Path $cloudInitFileNVA1) {
  # The command gets the contents of a file as one string, instead of an array of strings. 
  # By default, without the Raw dynamic parameter, content is returned as an array of newline-delimited strings
  $filecontentCloudInitNVA1 = Get-Content $cloudInitFileNVA1 -Raw
}
Else { Write-Warning "$(Get-Date) - $cloudInitFileNVA1 file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

Write-Host "$(Get-Date) - reading file:"$cloudInitFileNVA2
If (Test-Path -Path $cloudInitFileNVA2) {
  # The command gets the contents of a file as one string, instead of an array of strings. 
  # By default, without the Raw dynamic parameter, content is returned as an array of newline-delimited strings
  $filecontentCloudInitNVA2 = Get-Content $cloudInitFileNVA2 -Raw
}
Else { Write-Warning "$(Get-Date) - $cloudInitFileNVA2 file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }


# reading the input parameter file $inputParams and convert the values in hashtable 
#############################################
try {
  $arrayParams = (Get-Content -Raw $parametersFile | ConvertFrom-Json)
  $subscriptionName = $arrayParams.subscriptionName
  $resourceGroupName = $arrayParams.resourceGroupName
  $location = $arrayParams.location
  $locationhub1 = $arrayParams.locationhub1
  $locationhub2 = $arrayParams.locationhub2
  $locationspoke1 = $arrayParams.locationspoke1
  $locationspoke2 = $arrayParams.locationspoke2
  $locationspoke3 = $arrayParams.locationspoke3
  $locationspoke4 = $arrayParams.locationspoke4
  $adminUsername = $arrayParams.adminUsername
  $authenticationType = $arrayParams.authenticationType
  $adminPasswordOrKey = $arrayParams.adminPasswordOrKey
  $er_subscriptionId1 = $arrayParams.er_subscriptionId1
  $er_resourceGroup1 = $arrayParams.er_resourceGroup1
  $er_circuitName1 = $arrayParams.er_circuitName1
  $er_authorizationKey1 = $arrayParams.er_authorizationKey1
  $er_subscriptionId2 = $arrayParams.er_subscriptionId2
  $er_resourceGroup2 = $arrayParams.er_resourceGroup2
  $er_circuitName2 = $arrayParams.er_circuitName2
  $er_authorizationKey2 = $arrayParams.er_authorizationKey2

  Write-Host "$(Get-Date) - values from file: "$parametersFile -ForegroundColor Yellow
  if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }           else { Write-Host '   subscriptionName........: '$subscriptionName -ForegroundColor Yellow }
  if (!$resourceGroupName) { Write-Host 'variable $resourceGroupName is null' ; Exit }         else { Write-Host '   resourceGroupName.......: '$resourceGroupName -ForegroundColor Yellow }
  if (!$locationhub1) { Write-Host 'variable $locationhub1 is null' ; Exit }                   else { Write-Host '   locationhub1............: '$locationhub1 -ForegroundColor Yellow }
  if (!$locationhub2) { Write-Host 'variable $locationhub2 is null' ; Exit }                   else { Write-Host '   locationhub2............: '$locationhub2 -ForegroundColor Yellow }
  if (!$locationspoke1) { Write-Host 'variable $locationspoke1 is null' ; Exit }               else { Write-Host '   locationspoke1..........: '$locationspoke1 -ForegroundColor Yellow }
  if (!$locationspoke2) { Write-Host 'variable $locationspoke2 is null' ; Exit }               else { Write-Host '   locationspoke2..........: '$locationspoke2 -ForegroundColor Yellow }
  if (!$locationspoke3) { Write-Host 'variable $locationspoke3 is null' ; Exit }               else { Write-Host '   locationspoke3..........: '$locationspoke3 -ForegroundColor Yellow }
  if (!$locationspoke4) { Write-Host 'variable $locationspoke4 is null' ; Exit }               else { Write-Host '   locationspoke4..........: '$locationspoke4 -ForegroundColor Yellow }
  if (!$authenticationType) { Write-Host 'variable $authenticationType is null' ; Exit }       else { Write-Host '   authenticationType......: '$authenticationType -ForegroundColor Yellow }
  if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }                 else { Write-Host '   administrator username..: '$adminUsername -ForegroundColor Green }
  if (!$adminPasswordOrKey) { Write-Host 'variable $adminPasswordOrKey is null' ; Exit }       else { Write-Host '   adminPasswordOrKey......: '$adminPasswordOrKey -ForegroundColor Green }
  if (!$er_subscriptionId1) { Write-Host 'variable$er_subscriptionId1 is null' ; Exit }        else { Write-Host '   er_subscriptionId1......: '$er_subscriptionId1 -ForegroundColor Green }
  if (!$er_resourceGroup1) { Write-Host 'variable $er_resourceGroup1 is null' ; Exit }         else { Write-Host '   er_resourceGroup1.......: '$er_resourceGroup1 -ForegroundColor Green }
  if (!$er_circuitName1 ) { Write-Host 'variable $er_circuitName1  is null' ; Exit }           else { Write-Host '   er_circuitName1 ........: '$er_circuitName1 -ForegroundColor Green }
  if (!$er_authorizationKey1) { Write-Host 'variable $er_authorizationKey1  is null' ; Exit }  else { Write-Host '   er_authorizationKey1....: '$er_authorizationKey1 -ForegroundColor Green }

  if (!$er_subscriptionId2) { Write-Host 'variable$er_subscriptionId2 is null' ; Exit }        else { Write-Host '   er_subscriptionId2......: '$er_subscriptionId2 -ForegroundColor Green }
  if (!$er_resourceGroup2) { Write-Host 'variable $er_resourceGroup2 is null' ; Exit }         else { Write-Host '   er_resourceGroup2.......: '$er_resourceGroup2 -ForegroundColor Green }
  if (!$er_circuitName2 ) { Write-Host 'variable $er_circuitName2  is null' ; Exit }           else { Write-Host '   er_circuitName2 ........: '$er_circuitName2 -ForegroundColor Green }
  if (!$er_authorizationKey2) { Write-Host 'variable $er_authorizationKey2  is null' ; Exit }  else { Write-Host '   er_authorizationKey2....: '$er_authorizationKey2 -ForegroundColor Green }
} 
catch {
  Write-Host 'error in reading the template file: '$parametersFile -ForegroundColor Yellow
  Exit
}
          
$rgName = $ResourceGroupName
$location = $locationvnet1

$parameters = @{
  "adminUsername"        = $adminUsername;
  "authenticationType"   = $authenticationType;
  "adminPasswordOrKey"   = $adminPasswordOrKey;
  "locationhub1"         = $locationhub1;
  "locationhub2"         = $locationhub2;
  "cloudInitContentNVA1" = $filecontentCloudInitNVA1;
  "cloudInitContentNVA2" = $filecontentCloudInitNVA2;
  "er_subscriptionId1"   = $er_subscriptionId1;
  "er_resourceGroup1"    = $er_resourceGroup1;
  "er_circuitName1"      = $er_circuitName1;
  "er_authorizationKey1" = $er_authorizationKey1;
  "er_subscriptionId2"   = $er_subscriptionId2;
  "er_resourceGroup2"    = $er_resourceGroup2;
  "er_circuitName2"      = $er_circuitName2;
  "er_authorizationKey2" = $er_authorizationKey2
}

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

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