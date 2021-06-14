#
# Note: before running the script replace the correct values in the variables:
#  $subscriptionName: name of the Azure subscription
#  $adminUsername: name of Administrator username
#  $adminPassword: password of Administrator
#  $mngIP: public management IP used to connect to the Azure VM in SSH 
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='VMs administrator username')]
    [string]$adminUsername = "ADMINISTRATOR_USERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage='VMs administrator password')]
    [string]$adminPassword = "ADMINISTRATOR_PASSWORD"
    )
################# Input parameters #################
$subscriptionName  = "AzDev1"     
$location = "eastus"
$rgName = "test-rs"
$deploymentName = "vnets"
$armTemplateFile = "rs.json"

$RGTagExpireDate = '4/15/2021'
$RGTagContact = 'user1@contoso.com'
$RGTagNinja = 'user1'
$RGTagUsage = 'testing RS'
$mngIP = "REPLACE_THIS_STRING_WITH_YOUR_PUBLIC_MANAGEMENT_IP_USED_TO_CONNECT_IN _SSH_TO_THE_VM"
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"
$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword;
              "mngIP"        = $mngIP
              }


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group 
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }

# Add Tag Values to the Resource Group
Set-AzResourceGroup -Name $RGName -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Pathfinder=$RGTagNinja; Usage=$RGTagUsage} | Out-Null

$startTime=$(Get-Date)
$runTime=Measure-Command {
   write-host "$(Get-Date) - running ARM template:"$templateFile
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

$endTime=$(Get-Date)
write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime
write-host "end   time: "$endTime