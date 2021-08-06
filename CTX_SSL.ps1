###################################################
# Enable SSL on Citrix Broker Service             #
# Author: Sebastian Busch                         #
# EMail: sbusch@leitwerk.de                       #
####################################################
# Following variables need to accomplish this Script 
# Path to PFX 
# Passwort for PFX
# Remote Server 

# Collecting all Variables

# Getting PFX Path and store to string
function Get-FileName($InitialDirectory)
{
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.InitialDirectory = $InitialDirectory
    $OpenFileDialog.filter = "PFX (*.pfx) | *.pfx"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.FileName
}
$certificate = get-filename

# Request password to encrypt pfx
$mypwd = Read-Host 'Enter Your Password:' -AsSecureString

# Getting remote server. 
$ServerName = Read-Host 'Enter 2nd Server' 

# Import Certificate 
function Import-Certi {
Import-PfxCertificate -Exportable -FilePath $certificate -CertStoreLocation Cert:\LocalMachine\My -Password $mypwd
$Thumbprint = (Get-PfxData -Password $mypwd -FilePath $certificate).EndEntityCertificates.Thumbprint
$AppID = Get-WmiObject win32_product | where {$_.name -eq 'Citrix Broker Service'} 
$AppID = $AppID.IdentifyingNumber
write-host "Remove existing certificate bindings" 
netsh http delete sslcert ipport=0.0.0.0:443
write-host "Binding SSL Certificate on Port" 
netsh http add sslcert ipport=0.0.0.0:443 certhash=$Thumbprint appid=$AppID
write-host "Restarting Citrix Broker Service"
Restart-Service CitrixBrokerService
}
Import-Certi

#Switch to Server 2

#Copy Certificate to 2nd Server -> Please enable SMB ( Administrative Share )

New-Item -Path \\$ServerName\C$\Temp -type directory -Force 
Copy-Item -Path $certificate -Destination \\$ServerName\c$\Temp

# Import Remote Certificate
Invoke-Command -ComputerName $ServerName -ScriptBlock {
 $Server2CertPath = Get-Item -Path C:\Temp\*.PfX 
 Import-PfxCertificate -Exportable -FilePath $Server2CertPath.Fullname -CertStoreLocation Cert:\LocalMachine\My -Password $Using:mypwd
 $Thumbprint = (Get-PfxData -Password $Using:mypwd -FilePath $Server2CertPath.Fullname).EndEntityCertificates.Thumbprint
 $AppID = Get-WmiObject win32_product | where {$_.name -eq 'Citrix Broker Service'}
 $AppID = $AppID.IdentifyingNumber 
 write-host "Remove Remote existing certificate bindings" 
 netsh http delete sslcert ipport=0.0.0.0:443
 write-host "Binding Remote SSL Certificate on Port"
 netsh http add sslcert ipport=0.0.0.0:443 certhash=$Thumbprint appid=$AppID
 write-host "Restarting Remote Citrix Broker Service"
 Restart-Service CitrixBrokerService }

# Remove Remote Certificate File
Remove-Item -Path \\$ServerName\C$\Temp -Recurse -Force -Confirm:$false