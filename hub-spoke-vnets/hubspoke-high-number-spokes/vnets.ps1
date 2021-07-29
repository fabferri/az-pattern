#  Deployment vnets
#
# VARIABLES:
#   $subscriptionName: name of the Azure subscription ID
#   $location : Azure region where depoyed the smart router
#   $armTemplateFile: ARM template file
#
#

################# Input parameters #################
$subscriptionName = 'AzDev'
$location = 'northeurope'
### $rgName: the value of variable is stored in the file init.txt
$deploymentName = 'vnets'
$armTemplateFile = 'vnets.json'
#
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


# Load Initialization Variables
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
If (Test-Path -Path $ScriptDir\init.txt) {
        Get-Content $ScriptDir\init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

Write-Host 'Variables featched from the init.txt file:' -ForegroundColor Green
Write-Host $rgName -ForegroundColor Green
write-host $RGTagExpireDate -ForegroundColor Green
write-host $RGTagContact -ForegroundColor Green
write-host $RGTagNinja -ForegroundColor Green
write-host $RGTagUsage -ForegroundColor Green
write-host ''

# Create Resource Group 
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }


if ((Get-AzResourceGroup -Name $rgName).Tags -eq $null)
{
  # Add Tag Values to the Resource Group
  Set-AzResourceGroup -Name $rgName -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Pathfinder=$RGTagNinja; Usage=$RGTagUsage} | Out-Null
}

$startTime=$(Get-Date)
$runTime=Measure-Command {
  write-host "$(Get-Date)-running ARM template:"$templateFile -ForegroundColor Yellow
  New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -Verbose 
}

write-host "runtime: "$runTime.ToString() -ForegroundColor Yellow
write-host "start deployment: $startTime" -ForegroundColor Yellow
write-host "end deployment..: $(Get-Date)" -ForegroundColor Yellow