#
#
#  VARIABLES:
#    $subscriptionName: name of your Azure subscription where you want to deploy your Azure event hub
#    $location: Azure region to deploy the event hub
#    $armTemplateFile: arm template file to deploy the event hub
#    $IpMask: management IP, inclusive of subnetmask
#
#
################# Input parameters #################
$subscriptionName = 'Pathfinders'
$location = 'eastus2'   
$rgName = 'fab-servicetag1'
$deploymentName = 'udr-tag'
$armTemplateFile = 'eventhub.json'
$IpMask = '<YOUR_MANAGEMENT_IP/32'    
#
#
$RGTagExpireDate = '7/29/2021'
$RGTagContact = 'user1@contoso.com'
$RGTagNinja = 'user1'
$RGTagUsage = 'testing UDR tag'
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$parameters=@{
              "IpMask"= $IpMask
             }

# Create Resource Group 
Write-Host "$(Get-Date) - check Resource Group $rgName " -ForegroundColor Cyan
Try {
     $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'
     }
Catch {
       Write-Host "$(Get-Date) - create Resource Group $rgName " -ForegroundColor Cyan
       $rg = New-AzResourceGroup -Name $rgName  -Location $location  
       }

# set a tag on the resource group if it doesn't exist.
if ((Get-AzResourceGroup -Name $rgName).Tags -eq $null)
{
  # Add Tag Values to the Resource Group
  Set-AzResourceGroup -Name $rgName -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Pathfinder=$RGTagNinja; Usage=$RGTagUsage} | Out-Null
}

$startTime = "$(Get-Date)"
$runTime=Measure-Command {
   write-host "running ARM template:"$templateFile
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose
}
 
write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "endt time.: "$(Get-Date) -ForegroundColor Yellow