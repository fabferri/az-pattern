#
#
################# Input parameters #################
$subscriptionName= 'AzureDemo' 
$rgName = "test-IP"
$deploymentName = "depl"
$armTemplateFile = "public-ip.json"
$location = 'centralus'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id


# Create Resource Group step3
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try { Get-AzResourceGroup -Name $rgName  -ErrorAction Stop 
     Write-Host "$(Get-Date) - resource exists, skipping"}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }

$startTime = "$(Get-Date)"
$runTime=Measure-Command {
   write-host "$(Get-Date) - running ARM template:"$templateFile
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -Verbose 
}

write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "end  time.: "$(Get-Date) -ForegroundColor Yellow
