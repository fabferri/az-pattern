#
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='VMs administrator username')]
    [string]$adminUsername = "ADMINISTRATOR_USERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage='VMs administrator password')]
    [string]$adminPassword = "ADMINISTRATOR_PASSWORD",

    [Parameter(Mandatory = $false, HelpMessage='on-premises public IP for management')]
    [string]$mngIP = "100.0.0.10/32"
    )
################# Input parameters #################
$subscriptionName  = "Pathfinders"     
$location = "uksouth"
$rgName = "test-cloudinit"
$deploymentName = "vms"
$armTemplateFile = "vms.json"

$RGTagExpireDate = '03/25/21'
$RGTagContact = 'user1@contoso.com'
$RGTagNinja = 'user1'
$RGTagUsage = 'test cloud-init'
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"
$cloudInitFile  = "$pathFiles\cloud-init.txt"

If (Test-Path -Path $cloudInitFile) {
        # The commands in this example get the contents of a file as one string, instead of an array of strings. 
        # By default, without the Raw dynamic parameter, content is returned as an array of newline-delimited strings
        $filecontentCloudInit=Get-Content $cloudInitFile -Raw
        Write-Host $f -ForegroundColor Yellow
}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present.";Return}


$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword;
              "mngIP"= $mngIP;
              "cloudInitContent" = $filecontentCloudInit
              }
# print out the value of hash table
$parameters | ForEach-Object { $_ } 

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group 
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }

# Add Tag Values to the Resource Group
Set-AzResourceGroup -Name $RGName -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Pathfinder=$RGTagNinja; Usage=$RGTagUsage} | Out-Null


$runTime=Measure-Command {

write-host "$(Get-Date) running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters  -Verbose 
}

write-host "runtime: "$runTime.ToString() -ForegroundColor Yellow
write-host "$(Get-Date) - end execution time" -ForegroundColor Yellow