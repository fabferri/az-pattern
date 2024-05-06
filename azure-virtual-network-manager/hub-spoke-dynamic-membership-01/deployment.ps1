$inputParams = 'init.json'
$networkManagerName = "ntw-mgr1"
$connectivityConfigName ="netcfg1"

####################

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
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }                 else { Write-Host '  subscription name.......: '$subscriptionName -ForegroundColor Yellow }
if (!$location) { Write-Host 'variable $location is null' ; Exit }                                 else { Write-Host '  location................: '$location -ForegroundColor Yellow }
if (!$locationhub) { Write-Host 'variable $locationhub is null' ; Exit }                           else { Write-Host '  locationhub.............: '$locationhub -ForegroundColor Yellow }
if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }                               else { Write-Host '  location1...............: '$location1 -ForegroundColor Yellow }
if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }                               else { Write-Host '  location2...............: '$location2 -ForegroundColor Yellow }
if (!$location3) { Write-Host 'variable $location3 is null' ; Exit }                               else { Write-Host '  location3...............: '$location3 -ForegroundColor Yellow }
if (!$location4) { Write-Host 'variable $location4 is null' ; Exit }                               else { Write-Host '  location4...............: '$location4 -ForegroundColor Yellow }
if (!$resourceGroupName) { Write-Host 'variable $resourceGroupName is null' ; Exit }               else { Write-Host '  resource group name.....: '$resourceGroupName -ForegroundColor Yellow }
if (!$resourceGroupNameHubVNet) { Write-Host 'variable $resourceGroupNameHubVNet is null' ; Exit } else { Write-Host '  resourceGroupNameHubVNet: '$resourceGroupNameHubVNet -ForegroundColor Yellow }
if (!$resourceGroupNameVNet1) { Write-Host 'variable $resourceGroupNameVNet1 is null' ; Exit }     else { Write-Host '  resourceGroupNameVNet1..: '$resourceGroupNameVNet1 -ForegroundColor Yellow }
if (!$resourceGroupNameVNet2) { Write-Host 'variable $resourceGroupNameVNet2 is null' ; Exit }     else { Write-Host '  resourceGroupNameVNet2..: '$resourceGroupNameVNet2 -ForegroundColor Yellow }
if (!$resourceGroupNameVNet3) { Write-Host 'variable $resourceGroupNameVNet3 is null' ; Exit }     else { Write-Host '  resourceGroupNameVNet3..: '$resourceGroupNameVNet3 -ForegroundColor Yellow }
if (!$resourceGroupNameVNet4) { Write-Host 'variable $resourceGroupNameVNet1 is null' ; Exit }     else { Write-Host '  resourceGroupNameVNet4..: '$resourceGroupNameVNet4 -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }                       else { Write-Host '  administrator username..: '$adminUsername -ForegroundColor Green }
if (!$authenticationType) { Write-Host 'variable $authenticationType is null' ; Exit }             else { Write-Host '  authenticationType......: '$authenticationType -ForegroundColor Green }
if (!$adminPasswordOrKey) { Write-Host 'variable $adminPasswordOrKey is null' ; Exit }             else { Write-Host '  admin password/key......: '$adminPasswordOrKey -ForegroundColor Green }

############################################### CONNECT TO AZURE
$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
$SubscriptionId = $subscr.Id
$ResourceGroup= $resourceGroupName
$locations=@($location,$locationhub,$location1,$location2,$location3,$location4 )

$listLocations= $locations | Select-Object -Unique | Join-String -DoubleQuote -Separator ', '
Write-Host $listLocations -ForegroundColor Cyan


$Context = Get-AzContext
if ($Context -eq $null) {
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
########################################################################################
# ------------------------------------------
# get Bearer token for current user for Synapse Workspace API
$token = (Get-AzAccessToken -Resource "https://management.azure.com").Token
$headers = @{ Authorization = "Bearer $token" }
# ------------------------------------------


$uri = "https://management.azure.com/subscriptions/$SubscriptionId/"
$uri += "resourcegroups/$ResourceGroup/providers/Microsoft.Network/networkManagers/$networkManagerName/commit?api-version=2023-09-01"


$bodyNetworkManage = @"
{
        "targetLocations": [
          $listLocations
        ],
        "configurationIds": [
          "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/networkManagers/$networkManagerName/connectivityConfigurations/$connectivityConfigName"
        ],
        "commitType": "Connectivity"
}
"@

$result = try {Invoke-RestMethod -Method Post -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyNetworkManage } catch { $_.Exception.Response }

Write-Host ($result | ConvertTo-Json  -Depth 9) -ForegroundColor Green