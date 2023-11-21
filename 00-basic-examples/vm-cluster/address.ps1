# Before running the script set the variables:
#   $subscriptionName : name of the Azure subscription
#   $location         : Azure region when deployed the resource group
#   $rgName           : resource group name
#   $armTemplateFile  : ARM template file
################# Input parameters #################
$subscriptionName = "faber" 
$location         = "eastus"
$rgName           = "address01"
$deploymentName   = "address"
$armTemplateFile  = "address.json"
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group 
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {
    $rg = New-AzResourceGroup -Name $rgName  -Location $location  
}

$runTime = Measure-Command {
   write-host "(Get-Date) - running ARM template:"$templateFile
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -Verbose 
}

write-host "(Get-Date) - runtime: "$runTime.ToString() -ForegroundColor Yellow 

write-host "(Get-Date) - output values:" -ForegroundColor Yellow
$outputs = Get-AzResourceGroupDeployment -ResourceGroupName $rgName -Name $deploymentName

#print the hash values of JSON object "outputs": [] in ARM template
foreach ($e in $outputs.Outputs.Keys) {
    $key = $e
    $val = $outputs.Outputs[$key].Value
    write-host "key:"$key", value:"$val -ForegroundColor Yellow
}