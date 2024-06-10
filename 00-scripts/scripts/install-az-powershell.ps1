### install NuGet
Write-Host "Installing Azurepowershell Modules"
try {
    Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Stop | Out-Null
    Write-Host "  NuGet already registered, skipping"
}
catch {
    Install-PackageProvider -Name NuGet -Scope AllUsers  -Force | Out-Null
    Write-Host "  NuGet registered"
}

# install Azure powershell
#Get-ExecutionPolicy -List
#Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

if ($null -ne (Get-Module Az -ListAvailable)) {
    Write-Host "  Az.Account module already installed, skipping"
}
else {
    Install-Module -Name Az -Repository PSGallery -Scope AllUsers -Force | Out-Null
    Write-Host "  Az module installed"
}
