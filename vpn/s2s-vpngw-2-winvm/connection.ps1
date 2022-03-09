#
#
################# Input parameters #################
$subscriptionName  = "Pathfinders"     
$location = "uksouth"
$rgName = "fab-test-s2s-2"
$deploymentName = "connection"
$armTemplateFile = "connection.json"

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
Catch {write-host 'resource group does not exist!'  
       Exit
      }

$runTime=Measure-Command {
   write-host "$(Get-Date) running ARM template:"$templateFile
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile  -Verbose 
}

write-host "runtime: "$runTime.ToString() -ForegroundColor Yellow
write-host "$(Get-Date) - end execution time" -ForegroundColor Yellow