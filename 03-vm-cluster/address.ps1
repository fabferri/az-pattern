# Before running the script set the variables:
#
#   $subscriptionName : name of the Azure subscription
#   $location         : Azure region when deployed the resource group
#   $rgName           : resource group name
#   $armTemplateFile  : ARM template file
#   tags:
#       $RGTagExpireDate : expire date
#       $RGTagContact    : contact email
#       $RGTagUsage      : deployment purpose
#
################# Input parameters #################
$subscriptionName = "faber" 
$location         = "eastus"
$rgName           = "address01"
$deploymentName   = "address"
$armTemplateFile  = "address.json"
##
## tags
$RGTagExpireDate =((Get-Date).AddMonths(1)).ToString('yyyy-MM-dd')
$RGTagContact = 'user1@contoso.com' 
$RGTagAlias = 'user1' 
$RGTagUsage = 'address01' 

####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"

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
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -Verbose 
}

write-host "runtime: "$runTime.ToString() -ForegroundColor Yellow 

Write-Host (Get-Date)' - ' -NoNewline
write-host "output values:" -ForegroundColor Yellow
$outputs=get-AzResourceGroupDeployment -ResourceGroupName $rgName -Name $deploymentName

#print the hash values of JSON object "outputs": [] in ARM template
foreach ($e in $outputs.Outputs.Keys) {
    $key = $e
    $val = $outputs.Outputs[$key].Value
    write-host "key:"$key", value:"$val -ForegroundColor Yellow
}