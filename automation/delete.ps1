# Before running the script set the variables:
################# Input parameters #################
$subscriptionName = "AzDev" 
$location         = "eastus"
$rgName           = "Test-vm-00001"
$deploymentName   = "vm-delete"
$armTemplateFile  = "delete.json"
##
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group 
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {
    Write-Host '  resource group does not exists!'
    Exit
}

$runTime=Measure-Command {
   write-host "running ARM template:"$templateFile
   New-AzResourceGroupDeployment -Mode Complete -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -Verbose -Force 
}

write-host "runtime: "$runTime.ToString() -ForegroundColor Yellow 
write-host $(Date) -ForegroundColor Yellow 