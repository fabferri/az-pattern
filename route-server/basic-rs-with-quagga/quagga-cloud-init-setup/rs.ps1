#
# Note: before running the script replace the correct values in the variables:
#  $subscriptionName: name of the Azure subscription
#  $adminUsername: name of Administrator username
#  $adminPassword: password of Administrator
#  $mngIP: public management IP used to connect to the Azure VM in SSH. it can take the empty string
#
[CmdletBinding()]
param (
  [Parameter( Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'VMs administrator username')]
  [string]$adminUsername = "ADMINISTRATOR_USERNAME",
 
  [Parameter(Mandatory = $false, HelpMessage = 'VMs administrator password')]
  [string]$adminPassword = "ADMINISTRATOR_PASSWORD"
)
################# Input parameters #################
$subscriptionName = 'AzDev1'     
$location = 'northeurope'
$rgName = 'test-rs'
$deploymentName = 'vnets'
$armTemplateFile = 'rs.json'
$cloudInitFileName = 'cloud-init.txt'

$RGTagExpireDate = '7/15/2021'
$RGTagContact = 'user1@contoso.com'
$RGTagNinja = 'user1'
$RGTagUsage = 'testing RS with cloud-init'
$mngIP = ''
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$cloudInitFile = "$pathFiles\$cloudInitFileName"

Write-Host "@(get-date) - reading file:"$cloudInitFile
If (Test-Path -Path $cloudInitFile) {
  # The commands in this example get the contents of a file as one string, instead of an array of strings. 
  # By default, without the Raw dynamic parameter, content is returned as an array of newline-delimited strings
  $filecontentCloudInit = Get-Content $cloudInitFile -Raw
}
Else { Write-Warning "$(get-date) - $cloudInitFile file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

Write-Host "$(get-date) - file content $cloudInitFile :" -ForegroundColor Yellow
$filecontentCloudInit

$parameters = @{
  "location"         = $location;
  "adminUsername"    = $adminUsername;
  "adminPassword"    = $adminPassword;
  "cloudInitContent" = $filecontentCloudInit;
  "mngIP"            = $mngIP
}

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
Set-AzResourceGroup -Name $RGName -Tag @{Expires = $RGTagExpireDate; Contacts = $RGTagContact; Pathfinder = $RGTagNinja; Usage = $RGTagUsage } | Out-Null

$StartTime = $(Get-Date)

write-host "$(Get-Date) - running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow