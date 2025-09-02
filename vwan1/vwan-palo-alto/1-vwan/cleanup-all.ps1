$pathFiles  = Split-Path -Parent $PSCommandPath
$listFiles=@('.terraform','.terraform.lock.hcl','terraform.tfstate', 'main.tfplan', 'terraform.tfstate.backup')

foreach ($currentItemName in $listFiles) {
    $filePath = Join-Path -Path $pathFiles -ChildPath $currentItemName
    if (Test-Path $filePath) {
        Write-Host "deleting file: $currentItemName"
        Remove-Item -Path $filePath -Force
    } 
}
