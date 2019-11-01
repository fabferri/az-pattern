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
$rgName            = "rg-vpn"
$rgDeployment      = "deploy-vpn1"
$armTemplateFile   = "s2sVPN.json"
####################################################
$rg_csr            = "rg-csr"
$publiIPName_csr   = "csr-pubIP"
$ipLoopback_csr    = "172.168.1.1"
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


try {
  $IPcsr=Get-AzPublicIpAddress -Name $publiIPName_csr -ResourceGroupName $rg_csr -ErrorAction Stop
  if ($IPcsr) {
    write-host "CSR public IP: "$IPcsr.IpAddress -ForegroundColor Cyan 
  }
} 
catch {
  write-host "CSR public IP not found:" -ForegroundColor Yellow 
  write-host " -Check the resource group..:"$rg_csr  -ForegroundColor Yellow
  write-host " -check the CSR public IP...:"$publiIPName_csr -ForegroundColor Yellow
  Exit
}


$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword;
              "localGatewayIpAddress"= $IPcsr.IpAddress;
              "bgpPeeringAddress"= $ipLoopback_csr
              }

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$runTime=Measure-Command {
New-AzResourceGroup -Name $rgName -Location $location
write-host $templateFile
New-AzResourceGroupDeployment  -Name $rgDeployment -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose
}

write-host "runtime: "$runTime.ToString() -ForegroundColor Yellow