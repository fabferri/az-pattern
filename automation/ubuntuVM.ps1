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
    [string]$adminUsername = "ADMINISTRATOR_USERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage='password administrator VMs')]
    [string]$adminPassword = "ADMINISTRATOR_PASSWORD"
    )

################# Input parameters #################
$subscriptionName = "AzDev" 
$location         = "eastus"
$rgName           = "Test-vm-00001"
$deploymentName   = "vm-dev"
$armTemplateFile  = "ubuntuVM.json"
##
## tags
$RGTagExpireDate =((Get-Date).AddMonths(1)).ToString('yyyy-MM-dd')
$RGTagContact = 'user1@contoso.com' 
$RGTagAlias = 'user1' 
$RGTagUsage = 'test VM by Azure automation' 

####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"

$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword
              }

$TemplateURI="https://repo195471a7f0.blob.core.windows.net/home/ubuntuVM.json?sv=2019-07-07&sr=c&si=storage-policy&sig=CALTizVtnK0%2FB96JbGuCrhLF9AP78I8j1Ofcsr5wF4s%3D"

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
   New-AzResourceGroupDeployment -Mode incremental -ResourceGroupName $rgName -Name $deploymentName -TemplateUri $TemplateURI -TemplateParameterObject $parameters -verbose
}

write-host "runtime: "$runTime.ToString() -ForegroundColor Yellow 