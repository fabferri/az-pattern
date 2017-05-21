<#
#######################################################
### Description:
### Powershell script to capture the Windows system counters.
### the script is based on the powershell command Get-Counter
###
### Reference:
###    http://sqlblog.com/blogs/aaron_bertrand/archive/2011/01/31/how-i-use-powershell-to-collect-performance-counter-data.aspx
###
###
###  $hosts: Array of string cotaining the list of hosts (hostname,IP Address, local folder to store counters logs) where you want to pickup the system counters. 
###
### Useful powershell commands:
###   List of jobs          : PS> Get-Job
###   Receive the job output: PS> Receive-job -Id <Id_Number> -Keep
###   Remove all the jobs   : PS> Get-Job | Remove-Job -force
### 
#######################################################
#>

$hosts = @("h1","127.0.0.1","C:\1\"),
         @("h2","127.0.0.1","C:\2\"),
         @("h3","127.0.0.1","C:\3\")



##################### 
$func = {function CollectPerfAcrossServers 
{            
  param(            
         [string]$hostName,            
         [string]$hostIPAddress,            
         [string]$logFolder ,
         [int]$delay,
         [int]$count                   
       ) 

    write-host ">>> hostname            :" $hostName
    write-host ">>> IP Addr             :" $hostIPAddress
    write-host ">>> Folder              :" $logFolder
    write-host ">>> SamplingTime        :" $delay
    write-host ">>> NumSamples/counter  :" $count
    
    $delimiter = "`t"     
    $params = @("\Processor(_total)\% Processor Time",
         "\Processor(_total)\% User Time",
         "\Processor(_total)\% Privileged Time",
         "\Processor(_total)\Interrupts/sec",
         "\Processor(_total)\% DPC Time",
         "\Processor(_total)\DPCs Queued/sec",
         "\Processor(_total)\% Idle Time",
         "\Processor(_total)\% Interrupt Time",
         "\Memory\Page Faults/sec",
         "\Memory\Available Bytes",
         "\Memory\Committed Bytes",
         "\Memory\Commit Limit",
         "\Memory\Pages/sec",
         "\Memory\Available MBytes",
         "\PhysicalDisk(_total)\Current Disk Queue Length",
         "\PhysicalDisk(_total)\% Disk Time",
         "\PhysicalDisk(_total)\Avg. Disk Queue Length",
         "\PhysicalDisk(_total)\Avg. Disk Read Queue Length",
         "\PhysicalDisk(_total)\Avg. Disk Write Queue Length",
         "\PhysicalDisk(_total)\Avg. Disk sec/Transfer",
         "\PhysicalDisk(_total)\Avg. Disk sec/Read",
         "\PhysicalDisk(_total)\Avg. Disk sec/Write")

    # create a folder if it doesn't exist
    $b=test-path -path $logFolder -pathtype container
    if ($b -eq $false)
    {
       try
       {
           New-Item -ItemType Directory  -Path $logFolder -ErrorAction SilentlyContinue
        }
        catch
       {
           $ErrorMessage = $_.Exception.Message
           $FailedItem = $_.Exception.ItemName
           write-host "failure to create the folder $logFolder. The error message was $ErrorMessage"
       }
    }


    while($true)
    {       
       $metrics =Get-Counter -ComputerName $hostIPAddress -Counter $params -SampleInterval $delay -MaxSamples $count  
       
       foreach($metric in $metrics)            
       {            
           $obj = $metric.CounterSamples | Select-Object -Property Timestamp, Path, CookedValue;            
           # add these columns as data                      
           $obj | Add-Member -MemberType NoteProperty -Name Computer -Value $hostIPAddress -Force;      
           for ($i=0; $i -lt $obj.Count; $i++)
           {
               $str=$obj[$i].Path
               [int] $pos = $str.LastIndexOf('\');
               $rightPart = ($str.Substring($pos + 1)).Split(':')
               $counterName = $rightPart[0].Trim();

               $value=$obj[$i].CookedValue
               $timestamp=$obj[$i].Timestamp
               $record=$timestamp.ToString("dd-MM-yyyy HH:mm:ss",[System.Globalization.CultureInfo]::InvariantCulture)+$delimiter+$counterName+$delimiter+$value


               $File=$logFolder+$hostName+"-"+$i.ToString("00")+".txt"
               write-host -ForegroundColor Cyan $record
               out-file -Append -filepath $File  -inputobject $record -encoding ASCII  
               if ($i -eq ($obj.Count-1))
               { 
                   $str="-------------------------------------------------------"
                   write-host -ForegroundColor Yellow $str
               }
           }
       }
    } # end while
}
} #close function
##################### 

### Submit a job for every host we want to collect system counters.
foreach ($h in $hosts)
{
    $hostName = $h[0]
    $hostIPAddress=$h[1]
    $logFolder=$h[2]
    write-host "hostname:" $h[0] "- IPAddress:" $h[1] "- logFolder" $h[2]
    Start-Job -ScriptBlock { CollectPerfAcrossServers  $args[0] $args[1] $args[2] $args[3] $args[4]} -InitializationScript $func -ArgumentList @($hostName, $hostIPAddress, $logFolder, 5, 10); 
}
