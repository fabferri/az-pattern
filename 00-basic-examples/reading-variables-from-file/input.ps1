$inputFile= 'input.json'
$pathFiles  = Split-Path -Parent $PSCommandPath
$fullPathFile = "$pathFiles\$inputFile"

$jsonObj=Get-Content -Raw $fullPathFile | ConvertFrom-Json
if ($null -eq $jsonObj) {
    Write-Host "file $inputfile is empty"
    Exit
}

if ($jsonObj -is [psobject]) 
{
  $hash = @{}
  foreach ($property in $jsonObj.PSObject.Properties) {
      $hash[$property.Name] = $property.Value
  }
}
foreach($key in $hash.keys)
{
    $message = '{0} = {1} ' -f $key, $hash[$key]
    Write-Output $message
    Try {New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop}
    Catch {Set-Variable -Name $key -Value $hash[$key]}
        
}