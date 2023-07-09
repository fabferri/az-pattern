#
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='VMs administrator username')]
    [string]$adminUsername = "ADMINISTRATOR_USERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage='VMs administrator password')]
    [string]$adminPassword = "ADMINISTRATOR_PASSWORD"
    )

################# Input parameters #################
$subscriptionName  = "AzDev"     
$location          = "eastus"
$deploymentName    = "vpn-1"
$armTemplateFile   = "vpn1.json"
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"



#Reading the resource group name from the file init.txt
If (Test-Path -Path $pathFiles\init.txt) {
        Get-Content $pathFiles\init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}
        }
}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present.";Return}

if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit }
if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }
if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }
$rgName=$ResourceGroupName

$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword;
              "location1"= $location1;
              "location2"= $location2
              }

write-host "reading resource group name $ResourceGroupName from the file init.txt " -ForegroundColor Green
write-host "reading location1 name $location1 from the file init.txt " -ForegroundColor Green
write-host "reading location2 name $location2 from the file init.txt " -ForegroundColor Green
write-host "parameters variable:" $parameters.Values -ForegroundColor Yellow


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group step3
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }

$runTime=Measure-Command {

write-host "running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()