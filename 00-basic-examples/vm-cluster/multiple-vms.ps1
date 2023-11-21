# Before running the script set the variables:
#
#   $adminUsername    : administrator username
#   $adminPassword    : adminsitrator password
#   $subscriptionName : name of the Azure subscription
#   $location         : Azure region when deployed the resource group
#   $rgName           : resource group name
#   $armTemplateFile  : ARM template file
################# Input parameters #################
$adminUsername = "edge"
$adminPassword = "Verdicchio**2016"
$subscriptionName = "azDev1" 
$location = "francecentral"
$rgName = "vms0001"
$deploymentName = "vms"
$armTemplateFile = "multiple-vms.json"
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

$parameters = @{
    "adminUsername" = $adminUsername;
    "adminPassword" = $adminPassword
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

$runTime = Measure-Command {
    write-host "running ARM template:"$templateFile
    New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

write-host "runtime: "$runTime.ToString() -ForegroundColor Yellow 