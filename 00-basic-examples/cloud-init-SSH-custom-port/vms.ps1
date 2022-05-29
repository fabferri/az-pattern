################# Input parameters #################
$subscriptionName = 'AzDev1'   
$location = 'uksouth'
$rgName = 'test-cloudinit'
$deploymentName = 'vms'
$armTemplateFile = 'vms.json'

$RGTagExpireDate = '06/15/22'
$RGTagContact = 'user1@contoso.com'
$RGTagUsage = 'test cloud-init'
$mngIP = ''
$authenticationType = 'password'
$adminUsername = 'ADMINISTRATOR_USERNAME'
$adminPasswordOrKey = 'ADMINISTRATOR_PASSWORD'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$cloudInitFile = "$pathFiles\cloud-init.txt"

If (Test-Path -Path $cloudInitFile) {
    # The commands in this example get the contents of a file as one string, instead of an array of strings. 
    # By default, without the Raw dynamic parameter, content is returned as an array of newline-delimited strings
    $filecontentCloudInit = Get-Content $cloudInitFile -Raw
    Write-Host $f -ForegroundColor Yellow
}
Else { Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }


$parameters = @{
    "location"         = $location;
    "authenticationType" = $authenticationType
    "adminUsername"    = $adminUsername;
    "adminPasswordOrKey" = $adminPasswordOrKey;
    "mngIP"            = $mngIP;
    "cloudInitContent" = $filecontentCloudInit
}
# print out the value of hash table
$parameters | ForEach-Object { $_ } 

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group 
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
}
Catch { $rg = New-AzResourceGroup -Name $rgName  -Location $location }

# Add Tag Values to the Resource Group
Set-AzResourceGroup -Name $RGName -Tag @{Expires = $RGTagExpireDate; Contacts = $RGTagContact; Usage = $RGTagUsage } | Out-Null

$StartTime = Get-Date
write-host "$StartTime - running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters  -Verbose 

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow