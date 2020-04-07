# Before running the script set the variables:
#
#    $adminUsername    : administrator username
#    $adminPassword    : adminsitrator password
#    $subscriptionName : name of the Azure subscription
#
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='username administrator VMs')]
    [string]$adminUsername = "ADMINISTRATOR_USERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage='password administrator VMs')]
    [string]$adminPassword = "ADMINISTRATOR_PASSWORD"
    )

################# Input parameters #################
$subscriptionName  = "AzDev"     
$location          = "eastus"
$rgName            = "rg-lbha"
$deploymentName    = "ilbha"
$armTemplateFile   = "ilb-ha-ports.json"
##
## tags
$RGTagExpireDate = Get-Date -format "yyyy-MM-dd" 
$RGTagContact = 'user1@contoso.com' 
$RGTagAlias = 'user1' 
$RGTagUsage = 'check Azure ilb' 

####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"

$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword
              }

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
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

write-host "runtime: "$runTime.ToString() -ForegroundColor Yellow 