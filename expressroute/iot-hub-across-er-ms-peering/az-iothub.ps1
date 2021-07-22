################# Input parameters #################
$subscriptionName  = "AzureDemo2"     
$location          = "northeurope"
$rgName            = "IoT-1"
$rgDeployment      = "dep01"
$armTemplateFile   = "az-iothub.json"
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

#Create a resource group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group: $rgName " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
    }
Catch {
    $rg = New-AzResourceGroup -Name $rgName  -Location $location
    }

$runTime=Measure-Command {
  write-host "ARM template: "$templateFile -ForegroundColor Yellow
  New-AzResourceGroupDeployment  -Name $rgDeployment -ResourceGroupName $rgName -TemplateFile $templateFile -Verbose
}

write-host "runtime: "$runTime.ToString() -ForegroundColor Yellow