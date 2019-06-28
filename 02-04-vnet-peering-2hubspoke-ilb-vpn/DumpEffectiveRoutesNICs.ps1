#


$subscriptionName = "AzureDemo3"     
$rgName          = "4"
$nicName_nva_11  = "nva11-NIC1"
$nicName_nva_12  = "nva12-NIC1"
$nicName_nva_21  = "nva21-NIC1"
$nicName_nva_22  = "nva22-NIC1"
$nicName_vm1     = "vm1-NIC"
$nicName_vm2     = "vm2-NIC"
$nicName_vm3     = "vm3-NIC"
$nicName_vm4     = "vm4-NIC"
$nicName_vm5     = "vm5-NIC"
$nicName_vm6     = "vm6-NIC"

$nvaNICNameArray= @($nicName_nva_11, $nicName_nva_12, $nicName_nva_21,$nicName_nva_22,$nicName_vm1,$nicName_vm2,$nicName_vm3,$nicName_vm4,$nicName_vm5,$nicName_vm6) 

foreach ($e in $nvaNICNameArray)
{
  try {
    Get-AzNetworkInterface -Name $e -ResourceGroupName $rgName -ErrorAction Stop | Out-Null
  } catch {
    write-host "NIC"$e "not found" -ForegroundColor Green
   Exit
}
} ## end foreach

foreach ($e in $nvaNICNameArray)
{
  write-host "----------------------------------------------------------------------------" -ForegroundColor Green
  write-host "Effectiv2 routes in NIC: "$e  -ForegroundColor Cyan
  try {
    Get-AzEffectiveRouteTable -NetworkInterfaceName $e -ResourceGroupName $rgName -ErrorAction Stop | ft 
  } catch {
    write-host "Effetice routes in NIC"$e "not found" -ForegroundColor Green
    Exit
  } ## end foreach
}
