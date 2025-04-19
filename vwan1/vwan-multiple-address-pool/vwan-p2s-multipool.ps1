## script to create vnets, VMs and VPN Gateways
################# Input parameters #################
$deploymentName = 'vwan-deployment1'
$armTemplateFile = 'azuredeploy.json'
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
        Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
        Catch { Set-Variable -Name $key -Value $hash[$key] }
    }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }
   
# checking the values of variables from init-var.json
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '  subscription name..: '$subscriptionName -ForegroundColor Yellow }
if (!$resourceGroupName) { Write-Host 'variable $resourceGroupName is null' ; Exit } else { Write-Host '  resource group.....: '$resourceGroupName -ForegroundColor Yellow }
if (!$vwanName) { Write-Host 'variable $vwanName is null' ; Exit }                   else { Write-Host '  vwanName...........: '$vwanName -ForegroundColor Yellow }
if (!$hub1location) { Write-Host 'variable $hub1location is null' ; Exit }           else { Write-Host '  hub1location.......: '$hub1location -ForegroundColor Yellow }
if (!$hub1Name) { Write-Host 'variable $hub1Name is null' ; Exit }                   else { Write-Host '  hub1Name...........: '$hub1Name -ForegroundColor Yellow }
if (!$hub1_PublicCertificate1DataForP2S) { Write-Host 'variable $hub1_PublicCertificate1DataForP2S is null' ; Exit } else { Write-Host '  hub1_PublicCertificate1DataForP2S: '$hub1_PublicCertificate1DataForP2S -ForegroundColor Cyan }


$rgName = $resourceGroupName
$location = $hub1location

$parameters = @{
    "vwanName"                          = $vwanName;
    "hub1location"                      = $hub1location;
    "hub1Name"                          = $hub1Name;
    "hub1_PublicCertificate1DataForP2S" = $hub1_PublicCertificate1DataForP2S
}


$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Resource Group' -ForegroundColor Cyan
Try {
    Get-AzResourceGroup -Name $rgName -ErrorAction Stop
    Write-Host 'Resource exists, skipping'
}
Catch { New-AzResourceGroup -Name $rgName -Location $location }


$StartTime = Get-Date
Write-Host "$StartTime - ARM template:"$templateFile -ForegroundColor Yellow
New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow

write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "end time..: "$(Get-Date) -ForegroundColor Yellow