# Before running the script set the variables:
#
#   $adminUsername    : administrator username
#   $adminPassword    : adminsitrator password
#   $subscriptionName : name of the Azure subscription
#   $location         : Azure region when deployed the resource group
#   $rgName           : resource group name
#   $armTemplateFile  : ARM template file
#   tags:
#       $RGTagExpireDate : expire date
#       $RGTagContact    : contact email
#       $RGTagUsage      : deployment purpose
#
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='username administrator VMs')]
    [string]$adminUsername = "YOUR_ADMINISTRATOR_ACCOUNT",
 
    [Parameter(Mandatory = $false, HelpMessage='password administrator VMs')]
    [string]$adminPassword = "YOUR_ADMINISTRATOR_PASSWORD"
    )

################# Input parameters #################
$subscriptionName = "Az-MSDN" 
$location         = "eastus"
$rgName           = "lb1"
$deploymentName   = "ilb-multiple-be-fe"
$armTemplateFile  = "ilb-multiple-fe-be.json"
##
## tags
$RGTagExpireDate =((Get-Date).AddMonths(1)).ToString('yyyy-MM-dd')
$RGTagContact = 'user1@contoso.com' 
$RGTagAlias = 'user1' 
$RGTagUsage = 'ilb-multi-FE-BE' 

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
             -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Owner=$RGTagAlias; Usage=$RGTagUsage} | Out-Null
}

$runTime=Measure-Command {
   write-host "running ARM template:"$templateFile
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

write-host "runtime: "$runTime.ToString() -ForegroundColor Yellow 