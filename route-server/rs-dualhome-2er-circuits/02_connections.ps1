#
#
################# Input parameters #################
$subscriptionName  = "ExpressRoute-Lab"     
$location = "eastus"
$rgName = "ASH-Cust13-2"
$deploymentName = "vnets"
$armTemplateFile = "02_connections.json"

$RGTagExpireDate = '4/15/2021'
$RGTagContact = 'user01@contoso.com'
$RGTagNinja = 'user01'
$RGTagUsage = 'testing RS with multiple ER circuits'
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }

# Add Tag Values to the Resource Group
Set-AzResourceGroup -Name $RGName -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Pathfinder=$RGTagNinja; Usage=$RGTagUsage} | Out-Null


$runTime=Measure-Command {

write-host "$(Get-Date) - running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile  -Verbose 
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()
write-host "$(Get-Date) - end of deployment"