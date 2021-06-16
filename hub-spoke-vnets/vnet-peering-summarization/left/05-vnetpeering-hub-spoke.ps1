#
# variables:
#   $subscriptionName: Azure subscription name specified in file init.txt
#   $rgName: azure resource group specified in file init.txt
#   $location: Azure region specified in file init.txt
#
################# Input parameters #################
$deploymentName  = 'vnet-and-vms'
$initFile        = 'init.txt'
$armTemplateFile = '05-vnetpeering-hub-spoke.json'
$hubvnet         = 'hub00'
$spokevnet       = 'spoke01'
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"
$cloudInitFile  = "$pathFiles\cloud-init.txt"

# Load Initialization Variables
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Write-Host "$(get-date) - reading files from the folder:"$ScriptDir -ForegroundColor Yellow
If (Test-Path -Path $ScriptDir\$initFile) {
        Get-Content $ScriptDir\$initFile | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "$initFile not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

Write-Host "$(get-date) - reading from init.xt - subscriptioName: $subscriptionName " -ForegroundColor Cyan
Write-Host "$(get-date) - reading from init.xt - Resource Group.: $rgName " -ForegroundColor Cyan
Write-Host "$(get-date) - reading from init.xt - location.......: $location " -ForegroundColor Cyan



$parameters=@{
              "location" = $location;
              }

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

Try { Get-AzVirtualNetwork -Name $hubvnet -ResourceGroupName $rgName  -ErrorAction Stop
    }
Catch { Write-Host "hub vnet $hubvnet does not exist" ; Exit }


Try { Get-AzVirtualNetwork -Name $spokevnet -ResourceGroupName $rgName  -ErrorAction Stop
    }
Catch {  Write-Host "spoke vnet $spokevnet does not exist" ; Exit }



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