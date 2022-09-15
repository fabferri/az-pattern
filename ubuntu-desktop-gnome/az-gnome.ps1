###################### SET VARIABLES #################
$subscriptionName = "AzureDemo"
$location = "uksouth"
$rgName = "rg-gnome"
$armTemplateFile = "az-gnome.json"
$adminUsername = "ADMINISTRATOR_USERNAME"
$adminPassword = "ADMINISTRATOR_PASSWORD"
$rgGrpDeployment = "test-gnome"
$artifactsLocation = "https://raw.githubusercontent.com/fabferri/az-pattern/master/00-scripts/"
#
$parameters = @{
    "_artifactsLocation" = $artifactsLocation;
    "adminUsername" = $adminUsername;
    "authenticationType"= "password";
    "adminPasswordOrKey" = $adminPassword
}
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -Subscription $subscr.Id

# Create Resource Group 
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
}
Catch { $rg = New-AzResourceGroup -Name $rgName  -Location $location }

$StartTime = Get-Date
Write-Host "$StartTime - ARM template:"$templateFile -ForegroundColor Yellow
New-AzResourceGroupDeployment -Name $rgGrpDeployment -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow