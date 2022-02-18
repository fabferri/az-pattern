# Before running the script, customize the value of the variables in the init.json file
#
################# Input parameters #################
$deploymentName = "anm-vnets"
$armTemplateFile = "01-vnets.json"
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
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '   administrator password: '$adminPassword -ForegroundColor Green }
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$location) { Write-Host 'variable $location is null' ; Exit }                   else { Write-Host '   location..............: '$location -ForegroundColor Yellow }
if (!$locationhub) { Write-Host 'variable $locationhub is null' ; Exit }             else { Write-Host '   locationhub...........: '$locationhub -ForegroundColor Yellow }
if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }                 else { Write-Host '   location1.............: '$location1 -ForegroundColor Yellow }
if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }                 else { Write-Host '   location2.............: '$location2 -ForegroundColor Yellow }
if (!$location3) { Write-Host 'variable $location3 is null' ; Exit }                 else { Write-Host '   location3.............: '$location3 -ForegroundColor Yellow }
if (!$location4) { Write-Host 'variable $location4 is null' ; Exit }                 else { Write-Host '   location4.............: '$location4 -ForegroundColor Yellow }
if (!$resourceGroupName) { Write-Host 'variable $resourceGroupName is null' ; Exit }               else { Write-Host '   resource group name........: '$resourceGroupName -ForegroundColor Yellow }
if (!$resourceGroupNameHubVNet) { Write-Host 'variable $resourceGroupNameHubVNet is null' ; Exit } else { Write-Host '   resourceGroupNameHubVNet...: '$resourceGroupNameHubVNet -ForegroundColor Yellow }
if (!$resourceGroupNameVNet1) { Write-Host 'variable $resourceGroupNameVNet1 is null' ; Exit }     else { Write-Host '   resourceGroupNameVNet1.....: '$resourceGroupNameVNet1 -ForegroundColor Yellow }
if (!$resourceGroupNameVNet2) { Write-Host 'variable $resourceGroupNameVNet2 is null' ; Exit }     else { Write-Host '   resourceGroupNameVNet2.....: '$resourceGroupNameVNet2 -ForegroundColor Yellow }
if (!$resourceGroupNameVNet3) { Write-Host 'variable $resourceGroupNameVNet3 is null' ; Exit }     else { Write-Host '   resourceGroupNameVNet3.....: '$resourceGroupNameVNet3 -ForegroundColor Yellow }
if (!$resourceGroupNameVNet4) { Write-Host 'variable $resourceGroupNameVNet1 is null' ; Exit }     else { Write-Host '   resourceGroupNameVNet4.....: '$resourceGroupNameVNet4 -ForegroundColor Yellow }
if (!$mngIP) { Write-Host 'variable $mngIP is null' ; Exit }                         else { Write-Host '   mngIP.................: '$mngIP -ForegroundColor Yellow }
if (!$RGTagExpireDate) { Write-Host 'variable $RGTagExpireDate is null' ; Exit }     else { Write-Host '   RGTagExpireDate.......: '$RGTagExpireDate -ForegroundColor Yellow }
if (!$RGTagContact) { Write-Host 'variable $RGTagContact is null' ; Exit }           else { Write-Host '   RGTagContact..........: '$RGTagContact -ForegroundColor Yellow }
if (!$RGTagNinja) { Write-Host 'variable $RGTagNinja is null' ; Exit }               else { Write-Host '   RGTagNinja............: '$RGTagNinja -ForegroundColor Yellow }
if (!$RGTagUsage) { Write-Host 'variable $RGTagUsage is null' ; Exit }               else { Write-Host '   RGTagUsage............: '$RGTagUsage -ForegroundColor Yellow }
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


# Create Resource Group for the hub vnet
Write-Host "$(Get-Date) - Creating Resource Group $resourceGroupNameHubVNet " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $resourceGroupNameHubVNet  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
    Set-AzResourceGroup -Name $resourceGroupNameHubVNet -Tag @{Environment = "SHARED" }
}
Catch {
    $rg = New-AzResourceGroup -Name $resourceGroupNameHubVNet  -Location $locationhub  
    Set-AzResourceGroup -Name $resourceGroupNameHubVNet -Tag @{Environment = "SHARED" } 
}

# Create Resource Group for the vnet1
Write-Host "$(Get-Date) - Creating Resource Group $resourceGroupNameVNet1 " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $resourceGroupNameVNet1  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
    Set-AzResourceGroup -Name $resourceGroupNameVNet1 -Tag @{Environment = "ENG" } 
}
Catch {
    $rg = New-AzResourceGroup -Name $resourceGroupNameVNet1  -Location $location1  
    Set-AzResourceGroup -Name $resourceGroupNameVNet1 -Tag @{Environment = "ENG" } 
}

# Create Resource Group for the vnet2
Write-Host "$(Get-Date) - Creating Resource Group $resourceGroupNameVNet2 " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $resourceGroupNameVNet2  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
    Set-AzResourceGroup -Name $resourceGroupNameVNet2 -Tag @{Environment = "ENG" } 
}
Catch {
    $rg = New-AzResourceGroup -Name $resourceGroupNameVNet2  -Location $location2  
    Set-AzResourceGroup -Name $resourceGroupNameVNet2 -Tag @{Environment = "ENG" } 
}

# Create Resource Group for the vnet3
Write-Host "$(Get-Date) - Creating Resource Group $resourceGroupNameVNet3 " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $resourceGroupNameVNet3  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
    Set-AzResourceGroup -Name $resourceGroupNameVNet3 -Tag @{Environment = "PROC" } 
}
Catch {
    $rg = New-AzResourceGroup -Name $resourceGroupNameVNet3  -Location $location3  
    Set-AzResourceGroup -Name $resourceGroupNameVNet3 -Tag @{Environment = "PROC" } 
}

# Create Resource Group for the vnet4
Write-Host "$(Get-Date) - Creating Resource Group $resourceGroupNameVNet4 " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $resourceGroupNameVNet4  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
    Set-AzResourceGroup -Name $resourceGroupNameVNet4 -Tag @{Environment = "PROC" } 
}
Catch {
    $rg = New-AzResourceGroup -Name $resourceGroupNameVNet4  -Location $location4  
    Set-AzResourceGroup -Name $resourceGroupNameVNet4 -Tag @{Environment = "PROC" } 
}


# Create Resource Group 
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group $rgName " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
}
Catch {
    $rg = New-AzResourceGroup -Name $rgName  -Location $location  
    Set-AzResourceGroup -Name $rgName `
        -Tag @{Expires = $RGTagExpireDate; Contacts = $RGTagContact; Owner = $RGTagAlias; Usage = $RGTagUsage } | Out-Null
}

$parameters = @{ 
    "resourceGroupNameHubVNet" = $resourceGroupNameHubVNet;
    "resourceGroupNameVNet1" = $resourceGroupNameVNet1;
    "resourceGroupNameVNet2" = $resourceGroupNameVNet2;
    "resourceGroupNameVNet3" = $resourceGroupNameVNet3;
    "resourceGroupNameVNet4" = $resourceGroupNameVNet4;
    "locationhub" = $locationhub;
    "location1" = $location1;
    "location2" = $location2;
    "location3" = $location3;
    "location4" = $location4
}

$startTime = Get-Date
$runTime = Measure-Command {
    write-host "$startTime - running ARM template:"$templateFile
    New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

# End and printout the runtime
$endTime = Get-Date
$TimeDiff = New-TimeSpan $startTime $endTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Script completed" -ForegroundColor Green
Write-Host "  Time to complete: $RunTime" -ForegroundColor Yellow