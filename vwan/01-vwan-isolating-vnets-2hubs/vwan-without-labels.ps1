#
# The script read the init.json file and define the variables:
#   $adminUsername
#   $adminPassword
#   $subscriptionName
#   $ResourceGroupName
#   $hub1location
#   $hub2location
#   $hub1Name
#   $hub2Name
#   $mngIP
#   $RGTagExpireDate
#   $RGTagContact
#   $RGTagNinja
#   $RGTagUsage
#
################# Input parameters #################
$deploymentName = 'vwan1'
$armTemplateFile = 'vwan-without-labels.json'
$inputParams = 'init.json'
####################################################

$pathFiles  = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

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

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green}
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '   administrator password: '$adminPassword -ForegroundColor Green}
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name..: '$subscriptionName -ForegroundColor Yellow}
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit } else { Write-Host '   resource group name: '$ResourceGroupName -ForegroundColor Yellow}
if (!$hub1location) { Write-Host 'variable $hub1location is null' ; Exit }           else { Write-Host '   hub1 location...........: '$hub1location -ForegroundColor Yellow}
if (!$hub2location) { Write-Host 'variable $hub2location is null' ; Exit }           else { Write-Host '   hub2 location...........: '$hub2location -ForegroundColor Yellow}
if (!$hub1Name) { Write-Host 'variable $hub1Name is null' ; Exit }                   else { Write-Host '   hub1 name...............: '$hub1Name -ForegroundColor Yellow}
if (!$hub2Name) { Write-Host 'variable $hub2Name is null' ; Exit }                   else { Write-Host '   hub2 name...............: '$hub2Name -ForegroundColor Yellow}
if (!$mngIP) { Write-Host 'variable $mngIP is null' ;  }                             else { Write-Host '   mngIP..............: '$mngIP -ForegroundColor Yellow}

$rgName=$ResourceGroupName



$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Login Check
Try {Write-Host 'Using Subscription: ' -NoNewline
     Write-Host $((Get-AzContext).Name) -ForegroundColor Green}
Catch {
    Write-Warning 'You are not logged in dummy. Login and try again!'
    Return}


$parameters=@{
              "mngIP"= $mngIP;
              "hub1location"= $hub1location;
              "hub2location"= $hub2location;
              "hub1Name"= $hub1Name;
              "hub2Name"= $hub2Name;
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword
              }

# Create Resource Group
Write-Host "$(Get-Date) - Creating Resource Group: "$rgName -ForegroundColor Cyan
Try { Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host 'Resource exists, skipping'}
Catch { New-AzResourceGroup -Name $rgName -Location $hub1location}


$startTime = Get-Date
write-host "$startTime - running ARM template: "$templateFile -ForegroundColor Cyan
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

$endTime = Get-Date 
Write-Host "$$endTime - setup completed" -ForegroundColor Green

$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host "$(Get-Date) - Script completed" -ForegroundColor Green
Write-Host "Time to complete: "$runTime






