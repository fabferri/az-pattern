################# Load the value of parameters from init.json file #################
# Load Initialization Variables
$ScriptDir = Split-Path -Parent $PSCommandPath
If (Test-Path -Path $ScriptDir\init.json){
        $content=Get-Content -Raw -Path $ScriptDir\init.json 
}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

$json=ConvertFrom-Json -InputObject $content 

if ( $json -ne $null ) 
{
    foreach ($e in $json) 
    {
       if (-not([string]::IsNullOrEmpty($e.siteA))) { Write-Host (Get-Date)' - ' -NoNewline; Write-host "SiteA is not null.OK!" } else { Write-Host "siteA EMPTY" ; Return }
       if (-not([string]::IsNullOrEmpty($e.siteB))) { Write-Host (Get-Date)' - ' -NoNewline; Write-host "SiteB is not null.OK!" } else { Write-Host "siteB EMPTY" ; Return }
    }
}

if ($json.siteA.subscriptionName) { Write-host "siteA-subscription..:"$json.siteA.subscriptionName -ForegroundColor Green } else { Write-Host "siteA-subscription"; Return }
if ($json.siteA.csr1_vmName)      { Write-host "siteA-csr1 name.....:"$json.siteA.csr1_vmName -ForegroundColor Green }      else { Write-Host "siteA-csr1 name EMPTY"; Return }
if ($json.siteA.csr2_vmName)      { Write-host "siteA-csr2 name.....:"$json.siteA.csr2_vmName -ForegroundColor Green }      else { Write-Host "siteA-csr2 name EMPTY"; Return }
if ($json.siteA.adminUsername)    { Write-host "siteA-admin.........:"$json.siteA.adminUsername -ForegroundColor Green }    else { Write-Host "siteA-admin EMPTY"; Return }
if ($json.siteA.adminPassword)    { Write-host "siteA-admin pwd.....:"$json.siteA.adminPassword -ForegroundColor Green }    else { Write-Host "siteA-admin pwd EMPTY"; Return }
if ($json.siteA.location)         { Write-host "siteA-location......:"$json.siteA.location -ForegroundColor Green }         else { Write-Host "siteA-location EMPTY"; Return }
if ($json.siteA.rgName)           { Write-host "siteA-resource group:"$json.siteA.rgName -ForegroundColor Green }           else { Write-Host "siteA-resource group EMPTY"; Return }

if ($json.siteB.subscriptionName) { Write-host "siteB-subscription..:"$json.siteB.subscriptionName -ForegroundColor Cyan }  else { Write-Host "siteB-subscription"; Return }
if ($json.siteB.csr1_vmName)      { Write-host "siteB-csr1 name.....:"$json.siteB.csr1_vmName -ForegroundColor Cyan }       else { Write-Host "siteB-csr1 name EMPTY"; Return }
if ($json.siteB.csr2_vmName)      { Write-host "siteB-csr2 name.....:"$json.siteB.csr2_vmName -ForegroundColor Cyan }       else { Write-Host "siteB-csr2 name EMPTY"; Return }
if ($json.siteB.adminUsername)    { Write-host "siteB-admin.........:"$json.siteB.adminUsername -ForegroundColor Cyan }     else { Write-Host "siteB-admin EMPTY"; Return }
if ($json.siteB.adminPassword)    { Write-host "siteB-admin pwd.....:"$json.siteB.adminPassword -ForegroundColor Cyan }     else { Write-Host "siteB-admin pwd EMPTY"; Return }
if ($json.siteB.location)         { Write-host "siteB-location......:"$json.siteB.location -ForegroundColor Cyan }          else { Write-Host "siteB-location EMPTY"; Return }
if ($json.siteB.rgName)           { Write-host "siteB-resource group:"$json.siteB.rgName -ForegroundColor Cyan }            else { Write-Host "siteB-resource group EMPTY"; Return }
################# End parameters ###################

################# set the value of parameters before running the ARM template
$subscriptionName = $json.siteB.subscriptionName
$rgName  = $json.siteB.rgName
$location = $json.siteB.location
$armTemplateFile  = 'siteB.json'
$resourceGrpDeployment = 'siteB-deployment'


$parameters=@{
              "adminUsername"= $json.siteB.adminUsername;
              "adminPassword"= $json.siteB.adminPassword
              }
$templateFile       = "$ScriptDir\$armTemplateFile"


# selection of the Azure subscription 
$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group
Try {Get-AzResourceGroup -Name $rgName -ErrorAction Stop | Out-Null}
catch {
 Write-Host (Get-Date)' - ' -NoNewline
 Write-Host (Get-Date)'Create a new resource group $rgName' -NoNewline
 New-AzResourceGroup -Name $rgName -Location $location
}


$runTime=Measure-Command {
write-host 'ARM template: '$templateFile -ForegroundColor Yellow
### In incremental mode, Resource Manager leaves unchanged resources that exist in the resource group but aren't specified in the template. 
### Resources in the template are added to the resource group.
New-AzResourceGroupDeployment -Name $rgName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters  -Verbose 
}

Write-Host (Get-Date)' - ' -NoNewline
write-host  "runtime: "$runTime.ToString() -ForegroundColor Yellow
