###
### Create Azure keyvault
###
################# Input parameters #################
$subscriptionName = 'Pathfinders'
$objectId ='<GENERATED_OBJECT_ID>'  ##'GEN-AZUREAD-OBJECTID'
$location = 'eastus2'   
$rgName = 'fab-servicetag1'
$deploymentName = 'tag'
$armTemplateFile = 'keyvault.json'
#
#
$RGTagExpireDate = '7/29/2021'
$RGTagContact = 'user1@contoso.com'
$RGTagNinja = 'user1'
$RGTagUsage = 'testing UDR tag'
##

####################################################
$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$parameters=@{
               "location" = $location;
               "objectId" = $objectId
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
   write-host "$(Get-Date) - running ARM template:"$templateFile
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}
 
write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "endt time.: "$(Get-Date) -ForegroundColor Yellow