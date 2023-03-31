################# Input parameters #################
$deploymentName = 'consumer'
$armTemplateFile = 'consumer.json'
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
        #    Write-Output $message
        Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
        Catch { Set-Variable -Name $key -Value $hash[$key] }
    }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

# checking the values of variables
Write-Host "$(Get-Date) - reading variables value from the file: $inputParams" -ForegroundColor DarkRed

if (!$provider1SubscriptionName) { Write-Host 'variable $provider1SubscriptionName is null' ; Exit }    else { Write-Host ' provider1 subscription name..: '$provider1SubscriptionName -ForegroundColor Yellow }
if (!$provider2SubscriptionName) { Write-Host 'variable $provider2SubscriptionName is null' ; Exit }    else { Write-Host ' provider2 subscription name..: '$provider2SubscriptionName -ForegroundColor Yellow }
if (!$consumerSubscriptionName) { Write-Host 'variable $consumerSubscriptionName is null' ; Exit }      else { Write-Host ' consumer subscription name ..: '$consumerSubscriptionName -ForegroundColor Yellow }
if (!$provider1ResourceGroupName) { Write-Host 'variable $provider1ResourceGroupName is null' ; Exit }  else { Write-Host ' provider1 resource group name: '$provider1ResourceGroupName -ForegroundColor Cyan }
if (!$provider2ResourceGroupName) { Write-Host 'variable $provider2ResourceGroupName is null' ; Exit }  else { Write-Host ' provider2 resource group name: '$provider2ResourceGroupName -ForegroundColor Cyan }
if (!$consumerResourceGroupName) { Write-Host 'variable $consumerResourceGroupName is null' ; Exit }    else { Write-Host ' consumer resource group name.: '$consumerResourceGroupName -ForegroundColor Cyan }
if (!$provider1Location) { Write-Host 'variable $provider1Location is null' ; Exit }                    else { Write-Host ' provider1 location...........: '$provider1Location -ForegroundColor Yellow }
if (!$provider2Location) { Write-Host 'variable $locationProvider2 is null' ; Exit }                    else { Write-Host ' provider2 location...........: '$provider2Location -ForegroundColor Yellow }
if (!$consumerLocation) { Write-Host 'variable $consumerLocation is null' ; Exit }                      else { Write-Host ' consumer location ...........: '$consumerLocation -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }                            else { Write-Host ' administrator username.......: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }                            else { Write-Host ' administrator password.......: '$adminPassword -ForegroundColor Green }


$provider1AzureSubscriptionId = (Get-AzSubscription -SubscriptionName $provider1SubscriptionName).Id
$provider2AzureSubscriptionId = (Get-AzSubscription -SubscriptionName $provider2SubscriptionName).Id

$parameters = @{
    "provider1AzureSubscriptionId" = $provider1AzureSubscriptionId;
    "provider1ResourceGroupName"   = $provider1ResourceGroupName;
    "provider2AzureSubscriptionId" = $provider2AzureSubscriptionId;
    "provider2ResourceGroupName"   = $provider2ResourceGroupName;
    "location"                     = $consumerLocation;
    "adminUsername"                = $adminUsername;
    "adminPassword"                = $adminPassword
}

$subscriptionName = $consumerSubscriptionName
$rgName = $consumerResourceGroupName
$location = $consumerLocation

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id



# Create Resource Group 
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
}
Catch {
    $rg = New-AzResourceGroup -Name $rgName  -Location $location  
}


$StartTime = Get-Date
write-host "$StartTime - running ARM template: $templateFile"
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow