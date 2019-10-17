#
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='username administrator VMs')]
    [string]$adminUsername = "<ADMINISTRATOR_USERNAME>",
 
    [Parameter(Mandatory = $false, HelpMessage='password administrator VMs')]
    [string]$adminPassword = "<ADMINISTRATOR_PASSWORD>"
    )

################# Input parameters #################
$subscriptionName         = "AzDev"                  # Azure subscription name where is deployed consumer deployment
$location                 = "eastus"                 # Azure region of the consumer deployment
$rgName                   = "1-consumer"             # Resource group where is deployed consumer deployment
$rgDeployment             = "dep01"                  # deployment name of the consumer
$armTemplateFile          = "consumer-vnet-1er.json"  # ARM template of the consumer deployment
$rgNamePrivateServiceLink = "1-provider"             # resource group where is deployed the Private Service link
####################################################


$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id


### Check if the Resource Group where is deployed the private service link exists 
try { 
   Get-AzResourceGroup -Name $rgNamePrivateServiceLink -ErrorAction Stop
}
catch {
  write-host "Resoruce group where is deployed the Private Service link doesn't exist"
  Exit
}

## Check if the Resource Group contains private service link
try { 
   $pl=Get-AzPrivateLinkService  -ResourceGroupName $rgNamePrivateServiceLink -ErrorAction Stop
   if ($pl) {
      $privateLinkService_Name=$pl.Name
      write-host "private service link: "$privateLinkService_Name -ForegroundColor Cyan
   } else
   {
     write-host "private service link doesn't exist" -ForegroundColor Yellow
     Exit
   }
} 
catch {
    write-host "Resource group where is deployed the Private Service link doesn't exist"
    Exit
}


$privateLinkService_AzureSubscriptionId=$subscr.Id
$privateLinkService_ResourceGroup=$rgNamePrivateServiceLink
$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword;
              "privateLinkService_AzureSubscriptionId"=$privateLinkService_AzureSubscriptionId;
              "privateLinkService_ResourceGroup"=$privateLinkService_ResourceGroup;
              "privateLinkService_Name"=$privateLinkService_Name
              }
$runTime=Measure-Command {
New-AzResourceGroup -Name $rgName -Location $location
write-host $templateFile
New-AzResourceGroupDeployment  -Name $rgDeployment -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()