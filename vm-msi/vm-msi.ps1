################# Input parameters #################
$subscriptionName = 'AzDev1'     
$location = 'uksouth'
$rgName = 'vm-msi'
$deploymentName = 'vm01'
$armTemplateFile = 'vm-msi.json'

$adminUsername = 'ADMINISTRATOR_USERNAME'
$adminPasswordOrKey = 'ADMINISTRATOR_PASSWORD'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$parameters = @{
     "location"           = $location;
     "adminUsername"      = $adminUsername;
     "authenticationType" = "password"
     "adminPasswordOrKey" = $adminPasswordOrKey;
}

# Create Resource Group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group $rgName " -ForegroundColor Cyan
Try {
     $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'
}
Catch { $rg = New-AzResourceGroup -Name $rgName  -Location $location }

$startTime = Get-Date
write-host "$startTime - running ARM template:"$templateFile

New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

# End and printout the runtime
$endTime = Get-Date
$TimeDiff = New-TimeSpan $startTime $endTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Script completed" -ForegroundColor Green
Write-Host "  Time to complete: $RunTime" -ForegroundColor Yellow
