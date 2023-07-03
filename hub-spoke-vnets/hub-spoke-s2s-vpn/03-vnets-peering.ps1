################# Input parameters #################
$deploymentName = 'hubspoke-s2s'
$armTemplateFile = '03-vnets-peering.json'
$inputParams = 'init.json'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

# reading the input parameter file $inputParams and convert the values in hashtable 
If (Test-Path -Path $pathFiles\$inputParams) {
  # convert the json into PSCustomObject
  $jsonObj = Get-Content -Raw $pathFiles\$inputParams | ConvertFrom-Json
  if ($null -eq $jsonObj) {
    Write-Host "file $inputParams is empty"
    Exit
  }
  # convert the PSCustomObject in hashtable
  if ($jsonObj -is [psobject]) {
    $hash = @{}
    foreach ($property in $jsonObj.PSObject.Properties) {
      $hash[$property.Name] = $property.Value
    }
  }
  foreach ($key in $hash.keys) {
    $message = '{0} = {1} ' -f $key, $hash[$key]
    # Write-Output $message
    Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
    Catch { Set-Variable -Name $key -Value $hash[$key] }
  }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }     else { Write-Host '  subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit }   else { Write-Host '  resource group name...: '$ResourceGroupName -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }           else { Write-Host '  admin username........: '$adminUsername -ForegroundColor Green }
if (!$authenticationType) { Write-Host 'variable $authenticationType is null' ; Exit } else { Write-Host '  authentication type...: '$authenticationType -ForegroundColor Green }
if (!$adminPasswordOrKey) { Write-Host 'variable $adminPasswordOrKey is null' ; Exit } else { Write-Host '  admin password/key....: '$adminPasswordOrKey -ForegroundColor Green }
if (!$locationhub1) { Write-Host 'variable $locationhub1 is null' ; Exit }             else { Write-Host '  locationhub1..........: '$locationhub1 -ForegroundColor Yellow }
if (!$locationspoke1) { Write-Host 'variable $locationspoke1 is null' ; Exit }         else { Write-Host '  locationspoke1........: '$locationspoke1 -ForegroundColor Yellow }
if (!$locationspoke2) { Write-Host 'variable $locationspoke2 is null' ; Exit }         else { Write-Host '  locationspoke2........: '$locationspoke2 -ForegroundColor Yellow }
if (!$locationhub2) { Write-Host 'variable $locationhub2 is null' ; Exit }             else { Write-Host '  locationhub2..........: '$locationhub2 -ForegroundColor Yellow }
if (!$locationspoke3) { Write-Host 'variable $locationspoke3 is null' ; Exit }         else { Write-Host '  locationspoke3........: '$locationspoke3 -ForegroundColor Yellow }
if (!$locationspoke4) { Write-Host 'variable $locationspoke4 is null' ; Exit }         else { Write-Host '  locationspoke4........: '$locationspoke4 -ForegroundColor Yellow }                
$rgName = $ResourceGroupName
$location = $locationhub1

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$parameters = @{
  "locationhub1" = $locationhub1;
  "locationhub2" = $locationhub2
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