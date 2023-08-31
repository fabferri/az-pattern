################ INPUT VARIABLES ###################
$subscriptionName = 'AzDev'
$deploymentName = 'mykeyvault'
$armTemplateFile = 'keyvault.json'
$armParametersFile = 'keyvault-params.json'
$rgName = 'keyvault-test'
####################################################
$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$parametersFile = "$pathFiles\$armParametersFile"


try {
     $arrayParams = (Get-Content -Raw $parametersFile | ConvertFrom-Json)
     $location = $arrayParams.parameters.location.value
     $objectId = $arrayParams.parameters.objectId.value
     $secretName1 = $arrayParams.parameters.secretsObject.value.secrets.secretName[0]
     $secretValue1 = $arrayParams.parameters.secretsObject.value.secrets.secretValue[0]
     $secretName2 = $arrayParams.parameters.secretsObject.value.secrets.secretName[1]
     $secretValue2 = $arrayParams.parameters.secretsObject.value.secrets.secretValue[1]
     # checking the values of variables
     Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
     if (! $location) { Write-Host 'variable  $location is null' ; Exit }         else { Write-Host '   $location.......: ' $location -ForegroundColor Yellow }
     if (! $objectId) { Write-Host 'variable  $objectId is null' ; Exit }         else { Write-Host '   $objectId.......: ' $objectId -ForegroundColor Yellow }
     if (! $secretName1) { Write-Host 'variable $secretName1 is null' ; Exit }    else { Write-Host '   $secretName1....: ' $secretName1 -ForegroundColor Yellow }
     if (! $secretValue1) { Write-Host 'variable $secretValue1 is null' ; Exit }  else { Write-Host '   $secretValue1...: ' $secretValue1 -ForegroundColor Yellow }
     if (! $secretName2) { Write-Host 'variable $secretName2 is null' ; Exit }    else { Write-Host '   $secretName2....: ' $secretName2 -ForegroundColor Yellow }
     if (! $secretValue2) { Write-Host 'variable $secretValue2 is null' ; Exit }  else { Write-Host '   $secretValue2...: ' $secretValue2 -ForegroundColor Yellow }
}
catch {
     Write-Host 'error in reading the template file: '$parametersFile -ForegroundColor Yellow
     Exit
}


$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id


# Create Resource Group
Try {
     Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
     $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host '  resource exists, skipping'
}
Catch {
     $rg = New-AzResourceGroup -Name $rgName -Location $location  
}

$StartTime = Get-Date
Write-Host "$StartTime - ARM template:"$templateFile -ForegroundColor Yellow
New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterFile $parametersFile -Verbose

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow