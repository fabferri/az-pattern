#
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='VMs administrator username')]
    [string]$adminUsername = "ADMINISTRATOR_USERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage='VMs administrator password')]
    [string]$adminPassword = "ADMINISTRATOR_PASSWORD",

    [Parameter(Mandatory = $false, HelpMessage='on-premises public IP for management')]
    [string]$mngIP = "A.B.C.D/32"
    )
################# Input parameters #################
$subscriptionName  = "Pathfinders"     
$location = "uksouth"
$rgName = "s2s-win"
$deploymentName = "s2s"
$armTemplateFile = "s2s.json"

$RGTagExpireDate = '03/25/21'
$RGTagContact = 'user1@contoso.com'
$RGTagNinja = 'user1'
$RGTagUsage = 'test s2s with #2 Windows VM'
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"
$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword;
              "mngIP"= $mngIP
              }


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group 
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }

# Add Tag Values to the Resource Group
Set-AzResourceGroup -Name $RGName -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Pathfinder=$RGTagNinja; Usage=$RGTagUsage} | Out-Null


$runTime=Measure-Command {

write-host "$(Get-Date) running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

write-host "runtime: "$runTime.ToString() -ForegroundColor Yellow
write-host "$(Get-Date) - end execution time" -ForegroundColor Yellow