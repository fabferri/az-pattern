# ARM template action: 
#  - create the application gateway in spoke1 
#  - create Azure VMs as backend of Application Gateway
#  - by custom script extension install IIS in the windows VMs with web page pointing to the IP of the load balacner in the spoke2
#  - the IIS web page contains a link to the private endpoint for static web page running in Azure storage account
#
# Description of the input variables:
#    $deploymentName = name of the deployment
#    $armTemplateFile = name of the ARM template
#    $inputParams = input parameters used across all ARM templates
################ INPUT VARIABLES ###################
$deploymentName = 'spoke1Deployment'
$armTemplateFile = '06-spoke1.json'
$inputParams = 'init.json'
####################################################
$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"


if (Test-Path -Path $templateFile) { 
     Write-Host "$(Get-Date) - template file..: $templateFile " -ForegroundColor Cyan
}
else {
     Write-Host "$(Get-Date) - template file..: $templateFile not found!" -ForegroundColor Yellow
     Exit
} 

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
          Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
          Catch { Set-Variable -Name $key -Value $hash[$key] }
     }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }
   
# checking the values of variables from init-var.json
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '  subscription name......: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                       else { Write-Host '  resource group name....: '$rgName -ForegroundColor Yellow }
if (!$location) { Write-Host 'variable $location is null' ; Exit }                   else { Write-Host '  location...............: '$location -ForegroundColor Yellow }
if (!$locationonprem) { Write-Host 'variable $locationonprem is null' ; Exit }       else { Write-Host '  location on-premises...: '$locationonprem -ForegroundColor Yellow }
if (!$locationhub) { Write-Host 'variable $locationhub is null' ; Exit }             else { Write-Host '  location locationhub...: '$locationhub -ForegroundColor Yellow }
if (!$locationspoke1) { Write-Host 'variable $locationspoke1 is null' ; Exit }       else { Write-Host '  location locationspoke1: '$locationspoke1 -ForegroundColor Yellow }
if (!$locationspoke2) { Write-Host 'variable $locationspoke2 is null' ; Exit }       else { Write-Host '  location locationspoke2: '$locationspoke2 -ForegroundColor Yellow }
if (!$locationspoke3) { Write-Host 'variable $locationspoke3 is null' ; Exit }       else { Write-Host '  location locationspoke3: '$locationspoke3 -ForegroundColor Yellow }
if (!$vnetHubName) { Write-Host 'variable $vnetHubName is null' ; Exit }             else { Write-Host '  vnetHubName............: '$vnetHubName -ForegroundColor Green }
if (!$vnetOnprem) { Write-Host 'variable $vnetOnprem is null' ; Exit }               else { Write-Host '  vnetOnprem.............: '$vnetOnprem -ForegroundColor Green }
if (!$vnetspoke1) { Write-Host 'variable $vnetspoke1 is null' ; Exit }               else { Write-Host '  vnetspoke1.............: '$vnetspoke1 -ForegroundColor Green } 
if (!$vnetspoke2) { Write-Host 'variable $vnetspoke2 is null' ; Exit }               else { Write-Host '  vnetspoke2.............: '$vnetspoke2 -ForegroundColor Green }     
if (!$vnetspoke3) { Write-Host 'variable $vnetspoke3 is null' ; Exit }               else { Write-Host '  vnetspoke3.............: '$vnetspoke3 -ForegroundColor Green }
if (!$artifactsLocation) { Write-Host 'variable $artifactsLocation is null' ; Exit } else { Write-Host '  artifactsLocation......: '$artifactsLocation -ForegroundColor Cyan }  
if (!$gateway1Name) { Write-Host 'variable $gateway1Name is null' ; Exit }           else { Write-Host '  gateway1Name...........: '$gateway1Name -ForegroundColor Green }
if (!$gateway2Name) { Write-Host 'variable $gateway2Name is null' ; Exit }           else { Write-Host '  gateway2Name...........: '$gateway2Name -ForegroundColor Green }  
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '  adminUsername..........: '$adminUsername -ForegroundColor Cyan }   
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '  adminPassword..........: '$adminPassword -ForegroundColor Cyan }       
if (!$user1Name) { Write-Host 'variable $user1Name is null' ; Exit }                 else { Write-Host '  user1Name..............: '$user1Name -ForegroundColor Cyan }   
if (!$user1Password) { Write-Host 'variable $user1Password is null' ; Exit }         else { Write-Host '  user1Password..........: '$user1Password -ForegroundColor Cyan }
if (!$user2Name) { Write-Host 'variable $user2Name is null' ; Exit }                 else { Write-Host '  user2Name..............: '$user2Name -ForegroundColor Cyan }   
if (!$user2Password) { Write-Host 'variable $user2Password is null' ; Exit }         else { Write-Host '  user2Password..........: '$user2Password -ForegroundColor Cyan } 


$parameters = @{
     "locationonprem" = $locationonprem;
     "locationhub"    = $locationhub;
     "locationspoke1" = $locationspoke1;
     "locationspoke2" = $locationspoke2;
     "locationspoke3" = $locationspoke3;
     "adminUsername"  = $adminUsername;
     "adminPassword"  = $adminPassword;
     "user1Name"      = $user1Name;
     "user1Password"  = $user1Password;
     "user2Name"      = $user2Name;
     "user2Password"  = $user2Password;
     "_artifactsLocation" = $artifactsLocation
}

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group
Try {
     Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
     $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host '  resource exists, skipping'
}
Catch {
     $rg = New-AzResourceGroup -Name $rgName -Location $location  
}

$StartTime = Get-Date
Write-Host "$StartTime - ARM template:"$templateFile -ForegroundColor Yellow
New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow