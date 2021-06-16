#
# variables:
#   $subscriptionName: Azure subscription name specified in file init.txt
#   $rgName: azure resource group specified in file init.txt
#   $location: Azure region specified in file init.txt


################# Input parameters #################
$deploymentName  = 'rs'
$initFile        = 'init.txt'
$armTemplateFile = '03-rs.json'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"


Write-Host "$(Get-Date) - reading variables in the file: $initFile " -ForegroundColor Cyan

# Load Initialization Variables
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
If (Test-Path -Path $ScriptDir\$initFile) {
        Get-Content $ScriptDir\$initFile | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "$initFile not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

Write-Host "$(Get-Date) - reading from init.xt -subscriptioName: $subscriptionName " -ForegroundColor Cyan
Write-Host "$(Get-Date) - reading from init.xt -Resource Group.: $rgName " -ForegroundColor Cyan
Write-Host "$(Get-Date) - reading from init.xt -location.......: $location " -ForegroundColor Cyan


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id


# Create Resource Group step3
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }

$startTime=$(Get-Date)
$runTime=Measure-Command {
  write-host "$(Get-Date) - running ARM template:"$templateFile
  New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile  -Verbose 
}

$endTime=$(Get-Date)
write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime
write-host "end   time: "$endTime