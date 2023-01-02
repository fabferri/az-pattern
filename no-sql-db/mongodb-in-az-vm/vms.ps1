################# Input parameters #################
$subscriptionName = "AzDev"     
$location = "uksouth"
$rgName = "test-mongodb2"
$deploymentName = "vms"
$armTemplateFile = "vms.json"
$adminUsername = "ADMINISTRATOR_USERNAME"
$adminPassword = "ADMINISTRATOR_PASSWORD"
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$cloudInitFile = "$pathFiles\cloud-init-mongodb.txt"

If (Test-Path -Path $cloudInitFile) {
    # The commands in this example get the contents of a file as one string, instead of an array of strings. 
    # By default, without the Raw dynamic parameter, content is returned as an array of newline-delimited strings
    $filecontentCloudInit = Get-Content $cloudInitFile -Raw
    Write-Host $f -ForegroundColor Yellow
}
Else { Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }


$parameters = @{
    "adminUsername"    = $adminUsername;
    "adminPassword"    = $adminPassword;
    "cloudInitContent" = $filecontentCloudInit
}
# print out the value of hash table
$parameters | ForEach-Object { $_ } 

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group 
Try {
    Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
    $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
}
Catch { $rg = New-AzResourceGroup -Name $rgName  -Location $location }

$StartTime = Get-Date
write-host "$StartTime - running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters  -Verbose 

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow