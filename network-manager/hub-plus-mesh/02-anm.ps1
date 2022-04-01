# Before running the script set the values of the variables in the file init.json
#
################# Input parameters #################
$deploymentName = "anm1"
$armTemplateFile = "02-anm.json"
$inputParams = 'init.json'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

# reading the input parameter file $inputParams and convert the values in hashtable 
If (Test-Path -Path $pathFiles\$inputParams) {
     # convert the json into PSCustomObject
     $jsonObj = Get-Content -Raw $pathFiles\$inputParams | ConvertFrom-Json
     if ($null -eq $jsonObj) {
          Write-Host "file $inputParams is empty"
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
          $message = '{0} = {1} ' -f $key, $hash[$key]
          Write-Output $message
          Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
          Catch { Set-Variable -Name $key -Value $hash[$key] }
     }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '   administrator password: '$adminPassword -ForegroundColor Green }
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$location) { Write-Host 'variable $location is null' ; Exit }                   else { Write-Host '   location..............: '$location -ForegroundColor Yellow }
if (!$locationhubvnet) { Write-Host 'variable $locationhubvnet is null' ; Exit }     else { Write-Host '   locationhubvnet.......: '$locationhubvnet -ForegroundColor Yellow }
if (!$locationvnet1) { Write-Host 'variable $locationvnet1 is null' ; Exit }         else { Write-Host '   locationvnet1.........: '$locationvnet1 -ForegroundColor Yellow }
if (!$locationvnet2) { Write-Host 'variable $locationvnet2 is null' ; Exit }         else { Write-Host '   locationvnet2.........: '$locationvnet2 -ForegroundColor Yellow }
if (!$locationvnet3) { Write-Host 'variable $locationvnet3 is null' ; Exit }         else { Write-Host '   locationvnet3.........: '$locationvnet3 -ForegroundColor Yellow }
if (!$locationvnet4) { Write-Host 'variable $locationvnet4 is null' ; Exit }         else { Write-Host '   locationvnet4.........: '$locationvnet4 -ForegroundColor Yellow }
if (!$locationvnet5) { Write-Host 'variable $locationvnet5 is null' ; Exit }         else { Write-Host '   locationvnet5.........: '$locationvnet5 -ForegroundColor Yellow }
if (!$locationvnet6) { Write-Host 'variable $locationvnet6 is null' ; Exit }         else { Write-Host '   locationvnet6.........: '$locationvnet6 -ForegroundColor Yellow }
if (!$locationvnet7) { Write-Host 'variable $locationvnet7 is null' ; Exit }         else { Write-Host '   locationvnet7.........: '$locationvnet7 -ForegroundColor Yellow }
if (!$locationvnet8) { Write-Host 'variable $locationvnet8 is null' ; Exit }         else { Write-Host '   locationvnet8.........: '$locationvnet8 -ForegroundColor Yellow }
if (!$locationvnet9) { Write-Host 'variable $locationvnet9 is null' ; Exit }         else { Write-Host '   locationvnet9.........: '$locationvnet9 -ForegroundColor Yellow }
if (!$locationvnet10) { Write-Host 'variable $locationvnet10 is null' ; Exit }       else { Write-Host '   locationvnet10........: '$locationvnet10 -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit } else { Write-Host '   resource group name...: '$ResourceGroupName -ForegroundColor Yellow }
if (!$mngIP) { Write-Host 'variable $mngIP is null' -ForegroundColor Cyan }          else { Write-Host '   mngIP.................: '$mngIP -ForegroundColor Cyan }
if (!$RGTagExpireDate) { Write-Host 'variable $RGTagExpireDate is null' ; Exit }     else { Write-Host '   RGTagExpireDate.......: '$RGTagExpireDate -ForegroundColor Yellow }
if (!$RGTagContact) { Write-Host 'variable $RGTagContact is null' ; Exit }           else { Write-Host '   RGTagContact..........: '$RGTagContact -ForegroundColor Yellow }
if (!$RGTagNinja) { Write-Host 'variable $RGTagNinja is null' ; Exit }               else { Write-Host '   RGTagNinja............: '$RGTagNinja -ForegroundColor Yellow }
if (!$RGTagUsage) { Write-Host 'variable $RGTagUsage is null' ; Exit }               else { Write-Host '   RGTagUsage............: '$RGTagUsage -ForegroundColor Yellow }
$rgName = $ResourceGroupName

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Login Check
Try {
     Write-Host 'Using Subscription: ' -NoNewline
     Write-Host $((Get-AzContext).Name) -ForegroundColor Green
}
Catch {
     Write-Warning 'You are not logged in dummy. Login and try again!'
     Return
}

$parameters = @{ 
     "location" = $location;
     "resourceGroupNamehubVNet" = $ResourceGroupName;
     "resourceGroupNameVNet1" = $ResourceGroupName;
     "resourceGroupNameVNet2" = $ResourceGroupName;
     "resourceGroupNameVNet3" = $ResourceGroupName;
     "resourceGroupNameVNet4" = $ResourceGroupName;
     "resourceGroupNameVNet5" = $ResourceGroupName;
     "resourceGroupNameVNet6" = $ResourceGroupName;
     "resourceGroupNameVNet7" = $ResourceGroupName;
     "resourceGroupNameVNet8" = $ResourceGroupName;
     "resourceGroupNameVNet9" = $ResourceGroupName;
     "resourceGroupNameVNet10" = $ResourceGroupName
}

$startTime = Get-Date
$runTime = Measure-Command {
     write-host "$startTime - running ARM template:"$templateFile
     New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

# End and printout the runtime
$endTime = Get-Date
$TimeDiff = New-TimeSpan $startTime $endTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Script completed" -ForegroundColor Green
Write-Host "  Time to complete: $RunTime" -ForegroundColor Yellow