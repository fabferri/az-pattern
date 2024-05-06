###############################################
$inputParams = 'init.json'
###############################################

$pathFiles = Split-Path -Parent $PSCommandPath

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
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }            else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit }          else { Write-Host '   resource group name...: '$ResourceGroupName -ForegroundColor Yellow }
if (!$networkManagerName) { Write-Host 'variable $networkManagerName is null' ; Exit }        else { Write-Host '   networkManagerName....: '$networkManagerName -ForegroundColor Yellow }
if (!$connectivityConfigName) { Write-Host 'variable connectivityConfigName is null' ; Exit } else { Write-Host '   connectivityConfigName: '$connectivityConfigName -ForegroundColor Yellow }
if (!$location) { Write-Host 'variable $location is null' ; Exit }                            else { Write-Host '   location..............: '$location -ForegroundColor Yellow }
if (!$locationhub) { Write-Host 'variable $location is null' ; Exit }                         else { Write-Host '   locationhub...........: '$location -ForegroundColor Yellow }
if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }                          else { Write-Host '   location1.............: '$location1 -ForegroundColor Yellow }
if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }                          else { Write-Host '   location2.............: '$location2 -ForegroundColor Yellow }
if (!$location3) { Write-Host 'variable $location3 is null' ; Exit }                          else { Write-Host '   location3.............: '$location3 -ForegroundColor Yellow }
if (!$location4) { Write-Host 'variable $location4 is null' ; Exit }                          else { Write-Host '   location4.............: '$location4 -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }                  else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }                  else { Write-Host '   administrator password: '$adminPassword -ForegroundColor Green }

$ResourceGroup = $ResourceGroupName


$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id
$SubscriptionId = $subscr.Id

$Context = Get-AzContext
if ($null -eq $Context) {
    Write-Information "Need to login"
    Connect-AzAccount -Subscription $SubscriptionId
}
else
{
    Write-Host "Context exists"
    Write-Host "Current credential is $($Context.Account.Id)"
    if ($Context.Subscription.Id -ne $SubscriptionId) {
        $result = Select-AzSubscription -Subscription $SubscriptionId
        Write-Host "Current subscription is $($result.Subscription.Name)"
    }
    else {
        Write-Host "Current subscription is $($Context.Subscription.Name)"    
    }
}
#####################################################################
# get Bearer token for current user for Synapse Workspace API
$token = (Get-AzAccessToken -Resource "https://management.azure.com").Token
$headers = @{ Authorization = "Bearer $token" }
#####################################################################


$uri = "https://management.azure.com/subscriptions/$SubscriptionID/"
$uri += "resourcegroups/$ResourceGroup/providers/Microsoft.Network/networkManagers/$networkManagerName/commit?api-version=2022-01-01"


$bodyNetworkManage = @"
{
        "targetLocations": [
          "$location"
        ],
        "configurationIds": [
          "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/networkManagers/$networkManagerName/connectivityConfigurations/$connectivityConfigName"
        ],
        "commitType": "Connectivity"
}
"@

$result = Invoke-RestMethod -Method Post -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyNetworkManage

Write-Host ($result | ConvertTo-Json  -Depth 9) -ForegroundColor Green