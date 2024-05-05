# Before running the script set the variables in init.json file
################# Input parameters #################
$deploymentName = "anm1-vnet"
$armTemplateFile = "01-vnets-vms.json"
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

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group 
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group $rgName " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
}
Catch {
    $rg = New-AzResourceGroup -Name $rgName  -Location $location 
}

$parameters = @{ 
    "locationhub"   = $location;
    "location1"     = $location;
    "location2"     = $location;
    "location3"     = $location;
    "location4"     = $location;
    "adminUsername" = $adminUsername;
    "adminPassword" = $adminPassword
}

$startTime = Get-Date

write-host "$startTime - running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 


# End and printout the runtime
$endTime = Get-Date
$TimeDiff = New-TimeSpan $startTime $endTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Script completed" -ForegroundColor Green
Write-Host "  Time to complete: $RunTime" -ForegroundColor Yellow