# powershell script to create Azure SQL server and DBs
# Before running the script replace SQL_ADMINISTRATOR_USERNAME and SQL_ADMINISTRATOR_PASSWORD 
# in the variables $administratorLogin,$administratorLoginPassword
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='username administrator VMs')]
    [string]$administratorLogin = "SQL_ADMINISTRATOR_USERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage='password administrator VMs')]
    [string]$administratorLoginPassword = "SQL_ADMINISTRATOR_PASSWORD"
    )

################# Input parameters #################
$subscriptionName = "AzDev"                        ### name of the azure subscription
$location = "eastus"                               ### Azure region
$rgName = "sql-rg6"                                ### resource group name
$prefixSQLserverName = "sqlsrv"                    ### prefix of Azure SQL server name
$databaseList = @("testdb1","testdb2","testdb3")   ### list of databases
$dbSizeGB = 32                                     ### size of the DB in GByte
$fwRuleName ='AllowedIPs'                          ### name of the firewall rule to control access to the SQL server 
$startIp = "0.0.0.0"                               ### start ip address of firewall rule to allow to access your server
$endIp = "0.0.0.0"                                 ### end ip address of firewall rule to allow to access your server
####################################################


# Set server name - the logical server name has to be unique in the system
$randomName=Get-Random -SetSeed (Get-Date -UFormat "%Y%m%d") -Count 8 -InputObject @((48..57)+(97..122)) 
$suffix = New-Object System.String($randomName,0,$randomName.Length)
$serverName = $prefixSQLserverName+'-'+$suffix

### max length of the SQL server name
$maxLength=63 
### if the SQL server name is longer then the max length, the name is truncate
if ($serverName.Length -gt $maxLength) {$serverName=$serverName.subString(0,($maxLength)) }


### convert the GByte in byte
$dbSizeByte =[Int64]($dbSizeGB*1024*1024*1024)

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Set-AzContext -Subscription $subscr.Id -ErrorAction Stop

# Create Resource Group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource group $rgName exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }


$runTime=Measure-Command {

# Create the SQL server if doesn't exist
try { get-azsqlserver -ResourceGroupName $rgName -ServerName $serverName -ErrorAction Stop | Out-Null
      Write-Host "  Azure SQL server $serverName  exists, skipping"}
catch {
  Write-Host (Get-Date)' - ' -NoNewline
  Write-Host "Creating Azure SQL server $serverName" -ForegroundColor Cyan
  # Create a SQL server
  $server = New-AzSqlServer -ResourceGroupName $rgName `
      -ServerName $serverName `
      -Location $location `
      -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential `
      -ArgumentList $administratorLogin, $(ConvertTo-SecureString -String $administratorLoginPassword -AsPlainText -Force))
}

# Create a firewall rule for the SQL server 
try { get-AzSqlServerFirewallRule -FirewallRuleName $fwRuleName -ServerName $serverName -ResourceGroupName $rgName -ErrorAction Stop | Out-Null
      Write-Host "  firewall rule name $fwRuleName exists, skipping"
      }
catch {
       Write-Host (Get-Date)' - ' -NoNewline
       Write-Host "Creating firewall rule" -ForegroundColor Cyan
       # Create a server firewall rule that allows access from the specified IP range
       $serverFirewallRule = New-AzSqlServerFirewallRule -ResourceGroupName $rgName `
          -ServerName $serverName `
          -FirewallRuleName $fwRuleName -StartIpAddress $startIp -EndIpAddress $endIp
       }

# Create multiple DBs as specificed in the array $databaseList 
foreach ($db in $databaseList)
{
  try {
      get-AzSqlDatabase -DatabaseName $db -ServerName $serverName -ResourceGroupName $rgName -ErrorAction Stop | Out-Null
      Write-Host "  database: $db exists, skipping"
  }
  catch {
        Write-Host (Get-Date)' - ' -NoNewline
        Write-Host "Creating database: $db" -ForegroundColor Cyan
        # Create a blank database with an S0 performance level
        $database = New-AzSqlDatabase `
           -ResourceGroupName $rgName `
           -ServerName $serverName `
           -ComputeGeneration Gen5 `
           -Edition GeneralPurpose `
           -MinimumCapacity 4 `
           -VCore 4 `
           -DatabaseName $db `
           -CollationName 'SQL_Latin1_General_CP1_CI_AS' `
           -CatalogCollation 'SQL_Latin1_General_CP1_CI_AS' `
           -MaxSizeBytes $dbSizeByte `
           -LicenseType LicenseIncluded `
           -ReadScale Disabled `
           -ReadReplicaCount 0 


  } #end catch

   #check if the trasparent data Transparent Encryption on the DB is enabled.
   try{ 
    
     $dataEncryption= Get-AzSqlDatabaseTransparentDataEncryption -ServerName $serverName -ResourceGroupName $rgName -DatabaseName $db 
     $dataEncryptionState=[system.string]$dataEncryption.State
     
     if ($dataEncryptionState.Equals("Disabled")) { 
        Write-Host (Get-Date)' - ' -NoNewline
        Write-Host "  setting data transparent encryption in the database: $db" -ForegroundColor Cyan
        Set-AzSqlDatabaseTransparentDataEncryption  -ServerName $serverName -ResourceGroupName $rgName -DatabaseName $db -State Enabled -ErrorAction Stop | Out-Null
     }
     if ($dataEncryptionState.Equals("Enabled")) {
        Write-Host (Get-Date)' - ' -NoNewline
        Write-Host "   data transparent encryption already set in the database: $db" -ForegroundColor Cyan
     }
   }
   catch {
       write-host "error to set the transparent data encryption in the database: $db" -ForegroundColor Yellow
       } #end catch

} #end foreach


} ### end of Measure-Command

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()