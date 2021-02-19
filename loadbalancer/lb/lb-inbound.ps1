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
    [string]$adminPassword = "PUBLIC_RSA_KEY"
#    [string]$adminPassword = "ADMINISTRATOR_PASSWORD"
    )

################# Input parameters #################
$subscriptionName = "AzureDemo" 
$location         = "northeurope"
$rgName           = "lb-inbound1"
$deploymentName   = "lb-dev"
$armTemplateFile  = "lb-inbound.json"

### the variable $authenticationType can be assigned to possibile values: "sshPublicKey" OR "password". 
###   - set the value to "sshPublicKey" if you want to autheticate on Ubuntu VM by SSH with RSA keys
###   - set the value to "password" if you want to autheticate to the VM with password.
### DO NOT CONFUSE  $authenticationType with $adminPassword.
###
### $authenticationType = "sshPublicKey"   
### $authenticationType = "password"   
###
### the variable $windowsOrUbuntu can be aassigned to possibile values: "Windows" OR "Ubuntu". 
###  $windowsOrUbuntu    = "Ubuntu"
###  $windowsOrUbuntu    = "Windows"
###
$authenticationType = "sshPublicKey"
$windowsOrUbuntu    = "Ubuntu"

##
## tags
$RGTagExpireDate =((Get-Date).AddMonths(1)).ToString('yyyy-MM-dd')
$RGTagContact = 'user1@contoso.com' 
$RGTagAlias = 'user1' 
$RGTagUsage = 'dev VM' 

####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"

$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPasswordOrKey"= $adminPassword;
              "authenticationType"= $authenticationType;
              "windowsOrUbuntu" = $windowsOrUbuntu
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
write-host "-------------"
write-host "parameters:"
foreach($key in $parameters.keys)
{
    $message = '{0} : {1}' -f $key, $parameters[$key]
    Write-Host $message -ForegroundColor Cyan 
}

write-host ""
$runTime=Measure-Command {
   write-host "running ARM template: "$templateFile
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

write-host "runtime: "$runTime.ToString() -ForegroundColor Yellow 