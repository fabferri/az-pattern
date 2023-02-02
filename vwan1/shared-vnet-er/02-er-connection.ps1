#
#  variables in init.json file:
#   $subscriptionName: Azure subscription name for the vWAN
#   $ResourceGroupName: resource group name where is deployed the vWAN
#   $hub1location: Azure region to deploy the virtual hub1
#   $branch1location: Azure region to deploy the branch1
#   $hub1Name: name of the virtual hub1
#   $adminUsername: administrator username
#   $adminPassword: administrator password
#   $ercircuitSubcriptionId: Azure subscription ID where is deployed the ER circuit. This is different from  $subscriptionName
#   $ercircuitResourceGroup: "SEA-Cust33",
#   $erCircuitName: ExpressRoute circuit name
#   $erAuthorizationKey: autorization key is generated from the administrator of the ExpressRoute circuit. 
#                        it is required when the ExpressRoute circuit is deployed in diffeent subscription of the vWAN.
#
#
################# Input parameters #################
$deploymentName = 'vwan-site'
$armTemplateFile = '02-er-connection.json'
$inputParams = 'init.json'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

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
          Write-Output $message
          Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
          Catch { Set-Variable -Name $key -Value $hash[$key] }
     }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow

if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name..: '$subscriptionName -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit } else { Write-Host '   resource group name: '$ResourceGroupName -ForegroundColor Yellow }
if (!$vwanName) { Write-Host 'variable $ResourceGroupName is null' ; Exit }          else { Write-Host '   vWAN name..........: '$vwanName -ForegroundColor Yellow } 
if (!$hub1location) { Write-Host 'variable $hub1location is null' ; Exit }           else { Write-Host '   hub1 location......: '$hub1location -ForegroundColor Yellow }
if (!$hub1Name) { Write-Host 'variable $hub1Name is null' ; Exit }                   else { Write-Host '   hub1 name..........: '$hub1Name -ForegroundColor Yellow }
if (!$ercircuitSubcriptionId) { Write-Host 'variable $ercircuitSubcriptionId is null' ; Exit}  else { Write-Host '   ercircuitSubcriptionId..............: '$ercircuitSubcriptionId -ForegroundColor Yellow }
if (!$ercircuitResourceGroup) { Write-Host 'variable $ercircuitResourceGroup is null' ; Exit } else { Write-Host '   ercircuitResourceGroup..............: '$ercircuitResourceGroup -ForegroundColor Green }
if (!$erCircuitName) { Write-Host 'variable $erCircuitName is null' ; Exit }                   else { Write-Host '   erCircuitName.......................: '$erCircuitName -ForegroundColor Green }
if (!$erAuthorizationKey) { Write-Host 'variable $erAuthorizationKey is null' ; Exit }         else { Write-Host '   erAuthorizationKey..................: '$erAuthorizationKey -ForegroundColor Green }

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
     "hub1Name"               = $hub1Name;
     "ercircuitSubcriptionId" = $ercircuitSubcriptionId;
     "ercircuitResourceGroup" = $ercircuitResourceGroup;
     "erCircuitName"          = $erCircuitName;
     "erAuthorizationKey"     = $erAuthorizationKey
}


$location = $hub1location

# Create Resource Group
Write-Host "$(Get-Date) - Creating Resource Group: "$rgName -ForegroundColor Cyan
Try {
     Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host 'Resource exists, skipping'
}
Catch { New-AzResourceGroup -Name $rgName -Location $location }


$startTime = Get-Date
write-host "$(Get-Date) - running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

Write-Host "$(Get-Date) - setup completed" -ForegroundColor Green
$endTime = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Script completed" -ForegroundColor Green
Write-Host "Time to complete: "$runTime






