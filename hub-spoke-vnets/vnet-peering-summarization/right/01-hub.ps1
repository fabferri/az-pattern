# $subscriptionName: Azure subscription name specified in file init.txt
# $rgName: azure resource group specified in file init.txt
# $location: Azure region specified in file init.txt
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='VMs administrator username')]
    [string]$adminUsername = 'ADMINISTRATOR_USERNAME',
 
    [Parameter(Mandatory = $false, HelpMessage='SSH public key')]
    [string]$adminPassword = 'SSH_PUBLIC_KEY'
    )

################# Input parameters ################# 
$deploymentName    = 'hub-60'
$initFile          = 'init.txt'
$cloudInitFileName = 'cloud-init.txt'
$armTemplateFile   = '01-hub.json'
#
#
#
$RGTagExpireDate = '7/29/2021'
$RGTagContact = 'user1@contoso.com'
$RGTagNinja = 'user1'
$RGTagUsage = 'testing hub-spoke'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$cloudInitFile = "$pathFiles\$cloudInitFileName"

# Load Initialization Variables
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Write-Host "$(get-date) - reading files from the folder:"$ScriptDir -ForegroundColor Yellow
If (Test-Path -Path $ScriptDir\$initFile) {
        Get-Content $ScriptDir\$initFile | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "$initFile not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

Write-Host "$(get-date) - reading from init.xt - subscriptioName: $subscriptionName " -ForegroundColor Cyan
Write-Host "$(get-date) - reading from init.xt - Resource Group.: $rgName " -ForegroundColor Cyan
Write-Host "$(get-date) - reading from init.xt - location.......: $location " -ForegroundColor Cyan




If (Test-Path -Path $cloudInitFile) {
        # The commands in this example get the contents of a file as one string, instead of an array of strings. 
        # By default, without the Raw dynamic parameter, content is returned as an array of newline-delimited strings
        $filecontentCloudInit=Get-Content $cloudInitFile -Raw
        Write-Host $f -ForegroundColor Yellow
}
Else {Write-Warning "$(get-date) - $cloudInitFile file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present.";Return}

Write-Host "$(get-date) - file content $cloudInitFile :" -ForegroundColor Yellow
$filecontentCloudInit



$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPasswordOrKey"= $adminPassword;
              "location"= $location;
              "cloudInitContent" = $filecontentCloudInit
              }

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group step3
Write-Host "$(get-date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }

Write-Host "$(get-date) - checking presence of tags on the resource group $rgName" -ForegroundColor Cyan
# set a tag on the resource group if it doesn't exist.
if ((Get-AzResourceGroup -Name $rgName).Tags -eq $null)
{
  # Add Tag Values to the Resource Group
  Set-AzResourceGroup -Name $rgName -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Pathfinder=$RGTagNinja; Usage=$RGTagUsage} | Out-Null
}

$startTime=$(Get-Date)
$runTime=Measure-Command {
   Write-Host "$(get-date) - running ARM template:"$templateFile
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

$endTime=$(Get-Date)
write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime
write-host "end   time: "$endTime