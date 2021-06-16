#
# variables:
#   $subscriptionName: Azure subscription name specified in file init.txt
#   $rgName: azure resource group specified in file init.txt
#   $location: Azure region specified in file init.txt
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='VMs administrator username')]
    [string]$adminUsername = 'ADMINISTRATOR_USERNAME',
 
    [Parameter(Mandatory = $false, HelpMessage='SSH public key')]
    [string]$adminPassword = 'ADMINISTRATOR_PASSWORD'
    )

################# Input parameters #################   
$deploymentName    = 'vnet-and-vms'
$initFile          = 'init.txt'
$armTemplateFile   = '06-spoke-spoke.json'
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


# Load Initialization Variables
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
If (Test-Path -Path $ScriptDir\$initFile) {
        Get-Content $ScriptDir\$initFile | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "$initFile not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}
Write-Host "Reading from init.xt -subscriptioName: $subscriptionName " -ForegroundColor Cyan
Write-Host "Reading from init.xt -Resource Group.: $rgName " -ForegroundColor Cyan
Write-Host "Reading from init.xt -location.......: $location " -ForegroundColor Cyan


$parameters=@{
              "adminUsername" = $adminUsername;
              "authenticationType" = "password";
              "adminPasswordOrKey" = $adminPassword;
              "location" = $location
             }

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group step3
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }

$startTime=$(Get-Date)
$runTime=Measure-Command {
   write-host "running ARM template:"$templateFile
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

$endTime=$(Get-Date)
write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime
write-host "end   time: "$endTime