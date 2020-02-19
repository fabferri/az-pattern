# powershell script to deploy Azure SQL server adn DBs through the ARM template
#
# Before running the script replace SQL_ADMINISTRATOR_USERNAME and SQL_ADMINISTRATOR_PASSWORD 
# in the variables $administratorLogin,$administratorLoginPassword
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='username administrator VMs')]
    [string]$administratorLogin = "SQL_ADMINISTRATOR_USERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage='password administrator VMs')]
    [string]$administratorLoginPassword = "SQL_ADMINISTRATOR_PASSWORD"
    )

################# Input parameters #################
$subscriptionName   = "AzDev"     
$location           = "eastus"
$rgName             = "sql-rg4"
$rgDeployment       = "sqldepl"
$armTemplateFile    = "sql-dbs.json"
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"
$parameters=@{
              "administratorLogin"= $administratorLogin;
              "administratorLoginPassword"= $administratorLoginPassword
              }

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Set-AzContext -Subscription $subscr.Id -ErrorAction Stop

# Create Resource Group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }

$runTime=Measure-Command {
  New-AzResourceGroupDeployment  -Name $rgDeployment -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()