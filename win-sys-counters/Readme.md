#  Powershell script to capture Windows system counters


##### Filename: get-sys-counters.ps1
The powershell script is based on the **Get-Counter** command, to capture a list of windows system counters. The system parameters samples are stored in a single array:


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

the $params can be changed based on type of counters you want to pick up.

The Get-Counter command:

    Get-Counter -ComputerName $hostIPAddress -Counter $params -SampleInterval $delay -MaxSamples $count

provides the sampling interval ($delay) and the number of sampling values for every system counter.

Before running the script specify the list of target hosts in the array $hosts.
**$hosts** is an array of string containing the list of target hosts (hostname, IP Address, local folder to store counters logs)

Useful powershell commands to track the jobs:


- List of jobs          : PS> **Get-Job**
- Receive the job output: PS> **Receive-job -Id <Id_Number> -Keep**
- Remove all the jobs   : PS> **Get-Job | Remove-Job -force**

### Note
- To verify the the script on a local host only, set the value of IP addresses of the hosts to the loopback interface (127.0.0.1)
- the script can be used to get system counters on a list of Azure VMs; in this case the collector VMs, the administration credential are required to run on the target VMs.
- the script has been tested successfully in Azure jumpbox VM, attached to the same VNet of Azure Scale Set deployment.
