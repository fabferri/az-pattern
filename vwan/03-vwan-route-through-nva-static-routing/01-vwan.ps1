#
#  Vriables defined in init.json file:
# $adminUsername
# $adminPassword
# $subscriptionName
# $ResourceGroupName
# $hub1location
# $hub2location
# $branch1location
# $Branch2location
# $hub1Name
# $hub2Name
# $sharedKey
# $mngIP
# $RGTagExpireDate
# $RGTagContact
# $RGTagNinja
# $RGTagUsage
#
################# Input parameters #################
$deploymentName = 'vwan1'
$armTemplateFile = '01-vwan.json'
$inputParams = 'init.json'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

# reading the input parameter file $inputParams and convert the values in hashtable 
If (Test-Path -Path $pathFiles\$inputParams) 
{
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

Write-Host ''
# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit } else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit } else { Write-Host '   administrator password: '$adminPassword -ForegroundColor Green }
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit } else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit } else { Write-Host '   resource group name...: '$ResourceGroupName -ForegroundColor Yellow }
if (!$hub1location) { Write-Host 'variable $hub1location is null' ; Exit } else { Write-Host '   location1.............: '$hub1location -ForegroundColor Yellow }
if (!$hub2location) { Write-Host 'variable $hub2location is null' ; Exit } else { Write-Host '   location1.............: '$hub2location -ForegroundColor Yellow }
if (!$branch1location) { Write-Host 'variable $branch1location is null' ; Exit } else { Write-Host '   branch1 location......: '$branch1location -ForegroundColor Yellow }
if (!$branch2location) { Write-Host 'variable $branch2location is null' ; Exit } else { Write-Host '   branch2 location......: '$branch2location -ForegroundColor Yellow }
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit } else { Write-Host '   shared secret S2S -VPN: '$sharedKey -ForegroundColor Yellow }
if (!$mngIP) { Write-Host 'variable $mngIP is null' ; Exit } else { Write-Host '   mngIP.................: '$mngIP -ForegroundColor Cyan }
if (!$RGTagExpireDate) { Write-Host 'variable $RGTagExpireDate is null' ; Exit } else { Write-Host '   RGTagExpireDate.......: '$RGTagExpireDate -ForegroundColor Yellow }
if (!$RGTagContact) { Write-Host 'variable $RGTagContact is null' ; Exit } else { Write-Host '   RGTagContact..........: '$RGTagContact -ForegroundColor Yellow }
if (!$RGTagNinja) { Write-Host 'variable $RGTagNinja is null' ; Exit } else { Write-Host '   RGTagNinja............: '$RGTagNinja -ForegroundColor Yellow }
if (!$RGTagUsage) { Write-Host 'variable $RGTagUsage is null' ; Exit } else { Write-Host '   RGTagUsage............: '$RGTagUsage -ForegroundColor Yellow }
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
     "mngIP"         = $mngIP;
     "hub1location" = $hub1location;
     "hub2location" = $hub2location;
     "adminUsername" = $adminUsername;
     "adminPassword" = $adminPassword
}

$location = $hub1location
# Create Resource Group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Resource Group' -ForegroundColor Cyan
Try {
     $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host 'Resource exists, skipping'
}
Catch { $rg = New-AzResourceGroup -Name $rgName -Location $location }

# set a tag on the resource group if it doesn't exist.
if ((Get-AzResourceGroup -Name $rgName).Tags -eq $null) {
     # Add Tag Values to the Resource Group
     Set-AzResourceGroup -Name $rgName -Tag @{Expires = $RGTagExpireDate; Contacts = $RGTagContact; Pathfinder = $RGTagNinja; Usage = $RGTagUsage } | Out-Null
}

$startTime = "$(Get-Date)"
$runTime = Measure-Command {
     write-host "running ARM template:"$templateFile
     New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}
 
write-host "$(Get-Date)- runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "$(Get-Date)- start time: "$startTime -ForegroundColor Yellow
write-host "$(Get-Date)- end time..: "$(Get-Date) -ForegroundColor Yellow







