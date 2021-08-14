#
# the script read from the init.txt file the folloing variables:
#    $mngIP: public IP of the adminsitrator to access in SSH to the Azure VMs
#    $subscriptionName: Azure subscription   
#    $location1: Azure region
#    $ResourceGroupName: name of the resource group
#
################# Input parameters #################
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='VMs administrator username')]
    [string]$adminUsername = "ADMINISTRATOR_USERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage='VMs administrator password')]
    [string]$adminPassword = "ADMINISTRATOR_PASSWORD"
    )
#
$deploymentName = "nat1"
$armTemplateFile = "vnet-vms.json"
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"


#Reading the resource group name from the file init.txt
If (Test-Path -Path $pathFiles\init.txt) {
    Get-Content $pathFiles\init.txt | Foreach-Object{
    $var = $_.Split('=')
    Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
    Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}
    }
}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return}

if (!$mngIP) { Write-Host 'variable $mngIP is null' ; Exit }
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit }
if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }
$rgName=$ResourceGroupName

Write-Host 'management IP..........:'$mngIP -ForegroundColor Yellow
Write-Host 'azure subscription name:'$subscriptionName -ForegroundColor Yellow
Write-Host 'azure resource group...:'$rgName -ForegroundColor Yellow
Write-Host 'azure location1........:'$location1 -ForegroundColor Yellow

$parameters=@{
              "mngIP"= $mngIP;
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword;
              "location1"=$location1
              }

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id


# Create Resource Group step3
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try { Get-AzResourceGroup -Name $rgName  -ErrorAction Stop 
     Write-Host "$(Get-Date) - resource exists, skipping"}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location1  }

$startTime = "$(Get-Date)"
$runTime=Measure-Command {
   write-host "$(Get-Date) - running ARM template:"$templateFile
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "end  time.: "$(Get-Date) -ForegroundColor Yellow
