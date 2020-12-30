## Powershell script to deploy the Azure VNet and Linux VMs using different authetication methods: 
## -pair keys authetication 
##   or 
## -username and password 
##
## NOTE:
##   Before running the script set 
##   1. your Azure subscription name in the variable $subscriptionName
##   2. the name of your Azure resource group in the variable $rgName
##
##   Run the script by command:
##  .\vm -adminUsername YOUR_USERNAME -adminPasswordOrKey YOUR_PASSWORD|YOUR_PUBLIC_KEY -authenticationType sshPublicKey|password
##
##   To deploy Azure VM with key pair authetication:
##  .\vm -adminUsername YOUR_USERNAME  
##                                      
##  To deploy Azure VM with key pair authetication, with public key in command line:
##  .\vm -adminUsername YOUR_USERNAME -adminPasswordOrKey YOUR_PUBLIC_KEY    
##
##  To deploy Azure VM with username and password:
##  .\vm -adminUsername YOUR_USERNAME -adminPasswordOrKey YOUR_PASSWORD  -authenticationType password  
##  
##
## where:
##  YOUR_USERNAME: username of the adminsitrator of Azure VMs
##  YOUR_PASSWORD: password of the administrator of Azure VMs
##  YOUR_PUBLIC_KEY: public key of the administrator of Azure VMs
################# Input parameters #################
[CmdletBinding()]
param (
    [Parameter(Mandatory=$False, ValueFromPipeline=$false, HelpMessage='username administrator VMs')]
    [string]$adminUsername= "myadmin1",
 
    [Parameter(Mandatory = $False, HelpMessage='password administrator VMs')]
    [string]$adminPasswordOrKey,

    [Parameter(Mandatory = $False , HelpMessage='authetication type: sshPublicKey OR password')]
    [ValidateSet("sshPublicKey","password")]
    [string]$authenticationType="sshPublicKey"
    )


####################### SET VARIABLES #################
$subscriptionName      = "AzureDemo3"  # name of the Azure subscription
$location              = "eastus"      # name of the Azure location
$rgName                = "VM-1"        # name of the resource group
$resourceGrpDeployment = "basic-vm"    # name of the resource deployment
$armTemplateFile       = "vm.json"     # name of the ARM template to spin up the VMs
$FileName              = "id_rsa"      # filename public/private key for SSH connection

## if the variable $adminPasswordOrKey is not set (null), it will check the existance of authentication key
if ([string]::IsNullOrEmpty($adminPasswordOrKey))
{
  If  (Test-Path -Path "$HOME\.ssh\$FileName") {
    $PublicKey =  Get-Content "$HOME\.ssh\$FileName.pub" 
    write-host "public key: "$PublicKey -foregroundcolor Yellow
    $adminPasswordOrKey=$PublicKey.ToString()
  } Else
  {
    write-host "public key doesn't exit" -ForegroundColor Green
    Exit
  }
}

$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPasswordOrKey"= $adminPasswordOrKey;
              "authenticationType"=$authenticationType
              }
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"

# select the azure subscription
$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group 
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }

#deploy the ARM template
$runTime=Measure-Command {
 write-host "ARM template:"$templateFile -ForegroundColor Green
 New-AzResourceGroupDeployment -Mode Incremental -Name $resourceGrpDeployment -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()