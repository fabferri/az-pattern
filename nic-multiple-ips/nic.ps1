#
# powershell script to deploy the ARM template specified in the variable $armTemplateFile
#
################# Input parameters #################
$subscriptionName  = "AzDev"     
$location          = "eastus"
$rgName            = "nic2"
$deploymentName    = "nic1"
$armTemplateFile   = "nic.json"
##
## tags
$RGTagExpireDate = ((Get-Date).AddMonths(1)).ToString('yyyy-MM-dd')
$RGTagContact = 'user1@contoso.com' 
$RGTagAlias = 'user1' 
$RGTagUsage = 'multiple IPs associated with nic' 

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
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  
             Set-AzResourceGroup -Name $rgName `
             -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Pathfinder=$RGTagAlias; Usage=$RGTagUsage} | Out-Null
}

$runTime=Measure-Command {

write-host "running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -Verbose 
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()