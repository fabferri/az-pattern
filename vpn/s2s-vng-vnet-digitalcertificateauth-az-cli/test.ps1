$rgName = "test-s2s-cert2-powershell"
$gw1Name = "gw1"
$gw2Name = "gw2"

$seed = "$rgName-$gw1Name"
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($seed))
$suffix = [System.BitConverter]::ToString($hash).Replace("-", "").Substring(0, 6).ToLower()
$keyVault1Name = "kv-$gw1Name-$suffix"

write-host "keyVault1: "$keyVault1Name

$seed = "$rgName-$gw2Name"
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($seed))
$suffix = [System.BitConverter]::ToString($hash).Replace("-", "").Substring(0, 6).ToLower()
$keyVault2Name = "kv-$gw2Name-$suffix"

write-host "keyVault2: "$keyVault2Name