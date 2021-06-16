#
# variables:
#   $rgName: azure resource group specified in file init.txt
#
################# Input parameters ################# 
$location          = 'eastus2'
$deploymentName    = 'vnet-and-vms'
$initFile          = 'init.txt'
$armTemplateFile   = '02-er-gtw.json'
$er_resourceGroup  = 'ASH-Cust13'
$er_circuitName    = 'ASH-Cust13-ER'
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


# Load Initialization Variables
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
If (Test-Path -Path $ScriptDir\$initFile) {
        Get-Content $ScriptDir\$initFile | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "$initFile not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

Write-Host "$(Get-Date) - reading from init.xt -subscriptioName: $subscriptionName " -ForegroundColor Cyan
Write-Host "$(Get-Date) - reading from init.xt -Resource Group.: $rgName " -ForegroundColor Cyan
Write-Host "$(Get-Date) - reading from init.xt -location.......: $location " -ForegroundColor Cyan


$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$er_subscriptionId = $subscr.Id

# Create ER circuit
Write-Host "$(Get-Date) - Checking ExpressRoute circuit: $er_circuitName " -ForegroundColor Cyan
Try {$er = Get-AzExpressRouteCircuit -ResourceGroupName $er_resourceGroup -Name $er_circuitName  -ErrorAction Stop -WarningAction Ignore
     Write-Host '  ExpressRoute circuit $er_circuitName found!' -ForegroundColor Yellow}
Catch { Write-Host "$(Get-Date) - ExpressRoute $er_circuitName not found"; Exit}

## "er_subscriptionId" = $er_subscriptionId;
$parameters=@{ 
              "er_subscriptionId" = $er_subscriptionId;
              "er_resourceGroup" = $er_resourceGroup;
              "er_circuitName" = $er_circuitName
              }

# Create Resource Group step3
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }

$startTime=$(Get-Date)
$runTime=Measure-Command {
   write-host "$(Get-Date) - running ARM template:"$templateFile
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

$endTime=$(Get-Date)
write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime
write-host "end   time: "$endTime