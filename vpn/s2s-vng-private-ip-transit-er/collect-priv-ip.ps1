#
################# Input parameters #################
$deploymentName = "grabOutput"
$armTemplateFile = "collect-priv-ip.json"
$initFile = "init.txt"
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"


#Reading the resource group name from the file init.txt
If (Test-Path -Path $pathFiles\$initFile) {
    Get-Content $pathFiles\$initFile | Foreach-Object {
        $var = $_.Split('=')
        Try { New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop }
        Catch { if ($var[0] -ne "") {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()} }
    }
}
Else { Write-Warning "$initFile file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }
if (!$ResourceGroupName) { Write-Host "variable $ResourceGroupName is null"; Exit }


$rgName = $ResourceGroupName
write-host  "reading Resource Group name $ResourceGroupName from the file init.txt " -ForegroundColor yellow
$location = $location1

$parameters = @{
    "location1"     = $location1;
    "location2"     = $location2;

}

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group step3
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group $rgName " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
}
Catch { $rg = New-AzResourceGroup -Name $rgName  -Location $location }

$runTime = Measure-Command {

    write-host "running ARM template:"$templateFile
    New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()