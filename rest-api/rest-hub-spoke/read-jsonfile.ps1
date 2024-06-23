# $inputJsonfileName: json file with list of input variables
# 
$inputJsonfileName = 'init.json'
function readJsonInputFile {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $inputJsonFile
    )
    
    $pathFiles = Split-Path -Parent $PSCommandPath
    # reading the input parameter file $inputParams and convert the values in hashtable 
  If (Test-Path -Path $pathFiles\$inputJsonFile) {
    # convert the json into PSCustomObject
    $jsonObj = Get-Content -Raw $pathFiles\$inputJsonFile | ConvertFrom-Json
    if ($null -eq $jsonObj) {
         Write-Host "file $inputJsonFile is empty"
         Exit
    }
    # convert the PSCustomObject in hashtable
    if ($jsonObj -is [psobject]) {
         $hash = @{}
         foreach ($property in $jsonObj.PSObject.Properties) {
              $hash[$property.Name] = $property.Value
         }
    }
    foreach ($key in $hash.keys) {
         Try { New-Variable -Name $key -Value $hash[$key] -Scope Global -ErrorAction Stop }
         Catch { Set-Variable -Name $key -Value $hash[$key] -Scope Global}
    }
  } 
  else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }
  
  # checking the values of variables
  Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
  if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }                 else { Write-Host '  subscription name.........: '$subscriptionName -ForegroundColor Yellow }
  if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit }               else { Write-Host '  resource group name.......: '$ResourceGroupName -ForegroundColor Yellow }
  if (!$locationhub1) { Write-Host 'variable $locationhub1 is null' ; Exit }                         else { Write-Host '  locationhub1..............: '$locationhub1 -ForegroundColor Yellow }
  if (!$locationspoke1) { Write-Host 'variable $locationspoke1 is null' ; Exit }                     else { Write-Host '  locationspoke1............: '$locationspoke1 -ForegroundColor Yellow }
  if (!$locationspoke2) { Write-Host 'variable $locationspoke2 is null' ; Exit }                     else { Write-Host '  locationspoke2............: '$locationspoke2 -ForegroundColor Yellow }
  Write-Host ""
  if (!$hub1Name) { Write-Host 'variable $hub1Name is null' ; Exit }                                 else { Write-Host '  hub1Name..................: '$hub1Name -ForegroundColor Yellow }
  if (!$hub1AddressSpace1) { Write-Host 'variable $hub1AddressSpace1 is null' ; Exit }               else { Write-Host '  hub1AddressSpace1.........: '$hub1AddressSpace1 -ForegroundColor Yellow }
  if (!$hub1AddressSpace2) { Write-Host 'variable $hub1AddressSpace2 is null' ; Exit }               else { Write-Host '  hub1AddressSpace2.........: '$hub1AddressSpace2 -ForegroundColor Yellow }
  if (!$hub1subnet1Name) { Write-Host 'variable $hub1subnet1Name is null' ; Exit }                   else { Write-Host '  hub1subnet1Name...........: '$hub1subnet1Name -ForegroundColor Yellow }
  if (!$hub1subnet2Name) { Write-Host 'variable $hub1subnet2Name is null' ; Exit }                   else { Write-Host '  hub1subnet2Name...........: '$hub1subnet2Name -ForegroundColor Yellow }
  if (!$hub1subnet3Name) { Write-Host 'variable $hub1subnet3Name is null' ; Exit }                   else { Write-Host '  hub1subnet3Name...........: '$hub1subnet3Name -ForegroundColor Yellow }
  if (!$hub1subnet1AddressPrefix) { Write-Host 'variable $hub1subnet1AddressPrefix is null' ; Exit } else { Write-Host '  hub1subnet1AddressPrefix..: '$hub1subnet1AddressPrefix -ForegroundColor Yellow }
  if (!$hub1subnet2AddressPrefix) { Write-Host 'variable $hub1subnet2AddressPrefix is null' ; Exit } else { Write-Host '  hub1subnet2AddressPrefix..: '$hub1subnet2AddressPrefix -ForegroundColor Yellow }
  if (!$hub1subnet3AddressPrefix) { Write-Host 'variable $hub1subnet3AddressPrefix is null' ; Exit } else { Write-Host '  hub1subnet3AddressPrefix..: '$hub1subnet3AddressPrefix -ForegroundColor Yellow }
  Write-Host ""
  if (!$spoke1Name) { Write-Host 'variable $spoke1Name is null' ; Exit }                             else { Write-Host '  spoke1Name................: '$spoke1Name -ForegroundColor Yellow }    
  if (!$spoke1AddressSpace1) { Write-Host 'variable $spoke1AddressSpace1 is null' ; Exit }           else { Write-Host '  spoke1AddressSpace1.......: '$spoke1AddressSpace1 -ForegroundColor Yellow }
  if (!$spoke1AddressSpace2) { Write-Host 'variable $spoke1AddressSpace2 is null' ; Exit }           else { Write-Host '  spoke1AddressSpace2.......: '$spoke1AddressSpace2 -ForegroundColor Yellow }
  if (!$spoke1subnet1Name) { Write-Host 'variable $spoke1subnet1Name is null' ; Exit }               else { Write-Host '  spoke1subnet1Name.........: '$spoke1subnet1Name -ForegroundColor Yellow }
  if (!$spoke1subnet2Name) { Write-Host 'variable $spoke1subnet2Name is null' ; Exit }               else { Write-Host '  spoke1subnet2Name.........: '$spoke1subnet2Name -ForegroundColor Yellow }
  if (!$spoke1subnet3Name) { Write-Host 'variable $spoke1subnet3Name is null' ; Exit }               else { Write-Host '  spoke1subnet3Name.........: '$spoke1subnet3Name -ForegroundColor Yellow }
  if (!$spoke1subnet1AddressPrefix) { Write-Host 'variable $spoke1subnet1AddressPrefix is null' ; Exit } else { Write-Host '  spoke1subnet1AddressPrefix: '$spoke1subnet1AddressPrefix -ForegroundColor Yellow }
  if (!$spoke1subnet2AddressPrefix) { Write-Host 'variable $spoke1subnet2AddressPrefix is null' ; Exit } else { Write-Host '  spoke1subnet2AddressPrefix: '$spoke1subnet2AddressPrefix -ForegroundColor Yellow }
  if (!$spoke1subnet3AddressPrefix) { Write-Host 'variable $spoke1subnet3AddressPrefix is null' ; Exit } else { Write-Host '  spoke1subnet3AddressPrefix: '$spoke1subnet3AddressPrefix -ForegroundColor Yellow }
  Write-Host ""
  if (!$spoke2Name) { Write-Host 'variable $spoke2Name is null' ; Exit }                             else { Write-Host '  spoke2Name................: '$spoke2Name -ForegroundColor Yellow }    
  if (!$spoke2AddressSpace1) { Write-Host 'variable $spoke2AddressSpace1 is null' ; Exit }           else { Write-Host '  spoke2AddressSpace1.......: '$spoke2AddressSpace1 -ForegroundColor Yellow }
  if (!$spoke2AddressSpace2) { Write-Host 'variable $spoke2AddressSpace2 is null' ; Exit }           else { Write-Host '  spoke2AddressSpace2.......: '$spoke2AddressSpace2 -ForegroundColor Yellow }
  if (!$spoke2subnet1Name) { Write-Host 'variable $spoke2subnet1Name is null' ; Exit }               else { Write-Host '  spoke2subnet1Name.........: '$spoke2subnet1Name -ForegroundColor Yellow }
  if (!$spoke2subnet2Name) { Write-Host 'variable $spoke2subnet2Name is null' ; Exit }               else { Write-Host '  spoke2subnet2Name.........: '$spoke2subnet2Name -ForegroundColor Yellow }
  if (!$spoke2subnet3Name) { Write-Host 'variable $spoke2subnet3Name is null' ; Exit }               else { Write-Host '  spoke2subnet3Name.........: '$spoke2subnet3Name -ForegroundColor Yellow }
  if (!$spoke2subnet1AddressPrefix) { Write-Host 'variable $spoke2subnet1AddressPrefix is null' ; Exit } else { Write-Host '  spoke2subnet1AddressPrefix: '$spoke2subnet1AddressPrefix -ForegroundColor Yellow }
  if (!$spoke2subnet2AddressPrefix) { Write-Host 'variable $spoke2subnet2AddressPrefix is null' ; Exit } else { Write-Host '  spoke2subnet2AddressPrefix: '$spoke2subnet2AddressPrefix -ForegroundColor Yellow }
  if (!$spoke2subnet3AddressPrefix) { Write-Host 'variable $spoke2subnet3AddressPrefix is null' ; Exit } else { Write-Host '  spoke2subnet3AddressPrefix: '$spoke2subnet3AddressPrefix -ForegroundColor Yellow }
  Write-Host ""
  if (!$peeringhub1Tospoke1) { Write-Host 'variable $peeringhub1Tospoke1 is null' ; Exit }               else { Write-Host '  peeringhub1Tospoke1.......: '$peeringhub1Tospoke1 -ForegroundColor Yellow }
  if (!$peeringspoke1Tohub1) { Write-Host 'variable $peeringspoke1Tohub1 is null' ; Exit }               else { Write-Host '  peeringspoke1Tohub1.......: '$peeringspoke1Tohub1 -ForegroundColor Yellow }
  if (!$peeringhub1Tospoke2) { Write-Host 'variable $peeringhub1Tospoke2 is null' ; Exit }               else { Write-Host '  peeringhub1Tospoke2.......: '$peeringhub1Tospoke2 -ForegroundColor Yellow }
  if (!$peeringspoke2Tohub1) { Write-Host 'variable $peeringspoke2Tohub1 is null' ; Exit }               else { Write-Host '  peeringspoke2Tohub1.......: '$peeringspoke2Tohub1 -ForegroundColor Yellow }
  Write-Host ""
  if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }                           else { Write-Host '  adminUsername.............: '$adminUsername -ForegroundColor Green }
  if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }                           else { Write-Host '  adminPassword.............: '$adminPassword -ForegroundColor Green }
  
  }


readJsonInputFile -inputJsonFile $inputJsonfileName

  