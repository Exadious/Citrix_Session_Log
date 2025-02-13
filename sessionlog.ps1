# Version des Skripts
$ScriptVersion = "1.0.1"

# Ausführungsdatum
$ExecutionDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

# Funktion: Text-Banner anzeigen
function Show-Banner {
    $Banner = @"
*******************************************************
*                                                     *
*               Support-Info-Script!                  *
*                                                     *
*   Version: $ScriptVersion                           *
*   Date: $ExecutionDate                           	  *
*                                                     *
*   Please send the following file                    *
*   to your IT support.                               *
*                                                     *
*   /Desktop/SupportInfo.txt                          *
*                                                     *
*******************************************************
"@
    Write-Host $Banner -ForegroundColor Cyan
}

# Show Banner
Show-Banner

# Collect Userinformation
$UserName = $env:USERNAME
$ComputerName = $env:COMPUTERNAME

# Collect IP address(es)
$IPAddresses = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch "^(127\\.0\\.1)$" }).IPAddress -join ", "

# Get Kerberos-Tickets
try {
    $KlistOutput = klist | Out-String
} catch {
    $KlistOutput = "Error retrieving Kerberos tickets: $_"
}

# Get Storages
$Drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null }
$DrivesInfo = if ($Drives) {
    $Drives | ForEach-Object {
        $UNCPath = if ($_.DisplayRoot -ne $null) { $_.DisplayRoot } elseif ($_.Root -match "^\\\\") { $_.Root } else { "Local storage" }
        "$($_.Name): $UNCPath; Free Space: $([math]::Round($_.Free / 1GB, 2)) GB; Used Space: $([math]::Round($_.Used / 1GB, 2)) GB; Total storage space: $([math]::Round(($_.Used + $_.Free) / 1GB, 2)) GB"
    } | Out-String
} else {
    "No drives found."
}

# Hardware-Information
$CPU = (Get-CimInstance -ClassName Win32_Processor).Name -join ", "
$RAM = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$GPU = (Get-CimInstance -ClassName Win32_VideoController).Name -join ", "
$Mainboard = Get-CimInstance -ClassName Win32_BaseBoard | Select-Object -ExpandProperty Product
$BIOS = Get-CimInstance -ClassName Win32_BIOS | Select-Object -ExpandProperty SMBIOSBIOSVersion

# Network- and Systeminformation
$MACAddresses = (Get-NetAdapter | Select-Object -ExpandProperty MacAddress) -join ", "
$Gateway = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.DefaultGateway -ne $null }).DefaultGateway -join ", "
$DNS = (Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses -join ", "
$VPNConnections = (Get-VpnConnection | Select-Object -ExpandProperty Name) -join ", "
$FirewallStatus = (Get-NetFirewallProfile | ForEach-Object { "$($_.Name): $($_.Enabled)" }) -join ", "

# Software and peripherals
$OSVersion = (Get-ComputerInfo | Select-Object -ExpandProperty WindowsVersion)
$OSBuild = (Get-ComputerInfo | Select-Object -ExpandProperty WindowsBuildLabEx)
$InstalledSoftware = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion) | Out-String
$USBDevices = (Get-PnpDevice | Where-Object { $_.Class -eq 'USB' } | Select-Object -ExpandProperty FriendlyName) -join ", "
$Monitors = (Get-CimInstance -ClassName Win32_DesktopMonitor | ForEach-Object { "Name: $($_.Name), Resolution: $($_.ScreenWidth)x$($_.ScreenHeight)" }) -join ", "

# Define storage path
if ($env:SESSIONNAME -match "^ICA") {
    $OutputPath = "PROFILEPATH\DESKTOP\SupportInfo.txt"
} else {
    $OutputPath = "$env:USERPROFILE\Desktop\SupportInfo.txt"
}

# Compile information
$SupportInfo = @"
Execution Date: $ExecutionDate
Scriptversion: $ScriptVersion

Username: $UserName
Computername: $ComputerName
IP-Addresses: $IPAddresses

Hardware:
CPU: $CPU
RAM: $RAM GB
Graphics card(s): $GPU
Mainboard: $Mainboard
BIOS-Version: $BIOS

Netzwerk:
MAC-Addresses: $MACAddresses
Standardgateway: $Gateway
DNS-Server: $DNS
VPN-Connection: $VPNConnections
Firewall-Status: $FirewallStatus

Software:
OS: $OSVersion (Build $OSBuild)
Installed Software:
$InstalledSoftware

Peripherals:
USB-Devices: $USBDevices
Monitors: $Monitors

Kerberos-Tickets:
$KlistOutput

Storage:
$DrivesInfo
"@

# Output in file
$SupportInfo | Set-Content -Path $OutputPath -Encoding UTF8

# Userinformation Notification
Write-Host "Support information was successfully created and saved under: $OutputPath"
