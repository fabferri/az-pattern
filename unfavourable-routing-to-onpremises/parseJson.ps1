
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


if ($json.siteA.subscriptionName) { write-host "siteA-subscription..:"$json.siteA.subscriptionName -ForegroundColor Green } else { Write-Host "siteA-subscription"; Return }
if ($json.siteA.csr1_vmName)      { write-host "siteA-csr1 name.....:"$json.siteA.csr1_vmName -ForegroundColor Green }      else { Write-Host "siteA-csr1 name EMPTY"; Return }
if ($json.siteA.csr2_vmName)      { write-host "siteA-csr2 name.....:"$json.siteA.csr2_vmName -ForegroundColor Green }      else { Write-Host "siteA-csr2 name EMPTY"; Return }
if ($json.siteA.adminUsername)    { write-host "siteA-admin.........:"$json.siteA.adminUsername -ForegroundColor Green }    else { Write-Host "siteA-admin EMPTY"; Return }
if ($json.siteA.adminPassword)    { write-host "siteA-admin pwd.....:"$json.siteA.adminPassword -ForegroundColor Green }    else { Write-Host "siteA-admin pwd EMPTY"; Return }
if ($json.siteA.location)         { write-host "siteA-location......:"$json.siteA.location -ForegroundColor Green }         else { Write-Host "siteA-location EMPTY"; Return }
if ($json.siteA.rgName)           { write-host "siteA-resource group:"$json.siteA.rgName -ForegroundColor Green }           else { Write-Host "siteA-resource group EMPTY"; Return }

if ($json.siteB.subscriptionName) { write-host "siteB-subscription..:"$json.siteB.subscriptionName -ForegroundColor Cyan }  else { Write-Host "siteB-subscription"; Return }
if ($json.siteB.csr1_vmName)      { write-host "siteB-csr1 name.....:"$json.siteB.csr1_vmName -ForegroundColor Cyan }       else { Write-Host "siteB-csr1 name EMPTY"; Return }
if ($json.siteB.csr2_vmName)      { write-host "siteB-csr2 name.....:"$json.siteB.csr2_vmName -ForegroundColor Cyan }       else { Write-Host "siteB-csr2 name EMPTY"; Return }
if ($json.siteB.adminUsername)    { write-host "siteB-admin.........:"$json.siteB.adminUsername -ForegroundColor Cyan }     else { Write-Host "siteB-admin EMPTY"; Return }
if ($json.siteB.adminPassword)    { write-host "siteB-admin pwd.....:"$json.siteB.adminPassword -ForegroundColor Cyan }     else { Write-Host "siteB-admin pwd EMPTY"; Return }
if ($json.siteB.location)         { write-host "siteB-location......:"$json.siteB.location -ForegroundColor Cyan }          else { Write-Host "siteB-location EMPTY"; Return }
if ($json.siteB.rgName)           { write-host "siteB-resource group:"$json.siteB.rgName -ForegroundColor Cyan }            else { Write-Host "siteB-resource group EMPTY"; Return }

