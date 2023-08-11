#
#  variables in init.json file:
#   $adminUsername: administrator username
#   $adminPassword: administrator password
#   $subscriptionName: Azure subscription name
#   $ResourceGroupName: resource group name
#   $hub1location: Azure region to deploy the virtual hub1
#   $hub2location: Azure region to deploy the virtual hub2
#   $branch1location: Azure region to deploy the branch1
#   $branch2location: Azure region to deploy the branch2
#   $hub1Name: name of the virtual hub1
#   $hub2Name: name of the virtual hub2 
################# Input parameters #################
$deploymentName = 'log-analitics-azfw'
$armTemplateFile = '05-azfw-logs.json'
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
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit } else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit } else { Write-Host '   administrator password: '$adminPassword -ForegroundColor Green }
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit } else { Write-Host '   subscription name..: '$subscriptionName -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit } else { Write-Host '   resource group name: '$ResourceGroupName -ForegroundColor Yellow }
if (!$hub1location) { Write-Host 'variable $hub1location is null' ; Exit } else { Write-Host '   hub1 location......: '$hub1location -ForegroundColor Yellow }
if (!$hub2location) { Write-Host 'variable $hub2location is null' ; Exit } else { Write-Host '   hub2 location......: '$hub2location -ForegroundColor Yellow }
if (!$branch1location) { Write-Host 'variable $branch1location is null' ; Exit } else { Write-Host '   branch1 location...: '$branch1location -ForegroundColor Yellow }
if (!$branch2location) { Write-Host 'variable $branch2location is null' ; Exit } else { Write-Host '   branch2 location...: '$branch2location -ForegroundColor Yellow }
if (!$hub1Name) { Write-Host 'variable $hub1Name is null' ; Exit } else { Write-Host '   hub1 name..........: '$hub1Name -ForegroundColor Yellow }
if (!$hub2Name) { Write-Host 'variable $hub2Name is null' ; Exit } else { Write-Host '   hub2 name..........: '$hub2Name -ForegroundColor Yellow }
if (!$er1AddressPrefix) { Write-Host 'variable $er1AddressPrefix is null' ; Exit } else { Write-Host '   er1AddressPrefix...: '$er1AddressPrefix -ForegroundColor Yellow }
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
     "hub1location"     = $hub1location;
     "hub2location"     = $hub2location;
     "hub1Name"         = $hub1Name;
     "hub2Name"         = $hub2Name
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


$startTime = "$(Get-Date)"
$runTime = Measure-Command {
     write-host "running ARM template:"$templateFile
     New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}
 
write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "endt time.: "$(Get-Date) -ForegroundColor Yellow







