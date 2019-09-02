# 
# powershell script to query the web server 
# before running the script, set the variable $ipServer 
# $ipServer: frontend IPv6 public address of the Azure load balancer 
# 
$ipServer="2603:2021:710::1e8"

while ($true) {
try {
  $start = get-date
  $WebResponse = Invoke-WebRequest "http://[$ipServer]"
  $timetaken = [Int]((get-date) - $start).TotalMilliseconds
  foreach ($a in $WebResponse.AllElements)
  {
    if ($a.innerText -match  "Test Page 1")
    {
       write-host  $timetaken " " $a.innerText -ForegroundColor Cyan -BackgroundColor Black
       Break
    } #end if
    if ($a.innerText -match  "Test Page 2")
    {
       write-host $timetaken " " $a.innerText -ForegroundColor Yellow -BackgroundColor Black
       Break
    } #end if
  } ## end for loop
} catch [Exception] {
Write-Output ("{0} {1}" -f (get-date), $_.ToString())
} ## end try

} ## end while loop