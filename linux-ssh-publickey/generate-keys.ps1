### Script to generate the private and public keys for SSH authetication
### 
### the private and public key are store in the folder $HOME\.ssh\
### The config file $HOME\.ssh\config contains the cryptographic policy
###   MACs: define the configuration of message authentication code algorithms.
###   ServerAliveInterval: number of seconds that the client will wait before sending a null packet to the server 
###                        (to keep the connection alive).
###   ServerAliveCountMax: Sets the number of server alive messages which may be sent without ssh receiving any messages 
###                        back from the server. If this threshold is reached while server alive messages are
###                        being sent, ssh will disconnect from the server, terminating the session.
###                        The use of server alive messages is very different from TCPKeepAlive
###                        The server alive messages are sent through the encrypted channel and therefore will not be spoofable.
###
### The script creates a config file with following content:
###   MACs="hmac-sha2-512,hmac-sha1,hmac-sha1-96"
###   ServerAliveInterval=120
###   ServerAliveCountMax=30
###
$FileName = "id_rsa"
If (-not (Test-Path -Path "$HOME\.ssh\")) {New-Item "$HOME\.ssh\" -ItemType Directory | Out-Null}
If (-not (Test-Path -Path "$HOME\.ssh\config")) {
     $FileContent = "MACs=""hmac-sha2-512,hmac-sha1,hmac-sha1-96""`nServerAliveInterval=120`nServerAliveCountMax=30"
     Out-File -FilePath "$HOME\.ssh\config" -Encoding ascii -InputObject $FileContent -Force
}
If (-not (Test-Path -Path "$HOME\.ssh\$FileName")) {ssh-keygen.exe -t rsa -b 2048 -f "$HOME\.ssh\$FileName" -P """" | Out-Null}
Else {Write-Host "  Key Files exists, skipping"}
$PublicKey =  Get-Content "$HOME\.ssh\$FileName.pub" 
write-host "public key" -ForegroundColor Green
write-host $PublicKey -ForegroundColor Yellow