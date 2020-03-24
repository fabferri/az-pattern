[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='username administrator VMs')]
    [string]$adminUsername = "YOUR_ADMINISTRATOR_USER",
 
    [Parameter(Mandatory = $false, HelpMessage='password administrator VMs')]
    [string]$adminPassword = "YOUR_ADMINISTRATOR_PASSWORD"
    )

################# Input parameters #################
$subscriptionName      = "AzureDemo2"     
$location              = "eastus"
$rgName                = "peering01"
$rgDeployment          = "dep02"
$armTemplateFile       = "vms.json"
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"
$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword
              }

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id


$runTime=Measure-Command {

Try {Get-AzResourceGroup -Name $RGName -ErrorAction Stop | Out-Null}
catch {
 Write-Host (Get-Date)' - ' -NoNewline
 New-AzResourceGroup -Name $rgName -Location $location
}

write-host $templateFile
New-AzResourceGroupDeployment  -Name $rgDeployment -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose

} ## end Measure-Command
write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()