# Version des Skripts
$ScriptVersion = "1.0.3"

# Ausführungsdatum
$ExecutionDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

# Funktion: Text-Banner anzeigen
function Show-Banner {
    $Banner = @"
*******************************************************
*                                                     *
*       Willkommen zum Support-Info-Skript!           *
*                                                     *
*   Version: $ScriptVersion                           *
*   Datum: $ExecutionDate                       	    *
*                                                     *
*   Bitte senden sie folgende Datei                   *
*   Ihrem IT-Support                                  *
*                                                     *
*   /Desktop/SupportInfo.txt                          *
*                                                     *
*******************************************************
"@
    Write-Host $Banner -ForegroundColor Cyan
}

# Banner anzeigen
Show-Banner

# Benutzerinformationen erfassen
$UserName = $env:USERNAME
$ComputerName = $env:COMPUTERNAME

# IP-Adresse(n) erfassen
$IPAddresses = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch "^(1\\.0\\.1)$" }).IPAddress -join ", "

# Kerberos-Tickets abrufen
try {
    $KlistOutput = klist | Out-String
} catch {
    $KlistOutput = "Fehler beim Abrufen der Kerberos-Tickets: $_"
}

# Laufwerke erfassen
$Drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null }
$DrivesInfo = if ($Drives) {
    $Drives | ForEach-Object {
        $UNCPath = if ($_.DisplayRoot -ne $null) { $_.DisplayRoot } elseif ($_.Root -match "^\\\\") { $_.Root } else { "Lokales Laufwerk" }
        "$($_.Name): $UNCPath; Freier Speicherplatz: $([math]::Round($_.Free / 1GB, 2)) GB; Belegter Speicherplatz: $([math]::Round($_.Used / 1GB, 2)) GB; Gesamt Speicherplatz: $([math]::Round(($_.Used + $_.Free) / 1GB, 2)) GB"
    } | Out-String
} else {
    "Keine Laufwerke gefunden."
}

# Hardware-Informationen sammeln
$CPU = (Get-CimInstance -ClassName Win32_Processor).Name -join ", "
$RAM = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$GPU = (Get-CimInstance -ClassName Win32_VideoController).Name -join ", "
$Mainboard = Get-CimInstance -ClassName Win32_BaseBoard | Select-Object -ExpandProperty Product
$BIOS = Get-CimInstance -ClassName Win32_BIOS | Select-Object -ExpandProperty SMBIOSBIOSVersion

# Netzwerk- und Systeminformationen
$MACAddresses = (Get-NetAdapter | Select-Object -ExpandProperty MacAddress) -join ", "
$Gateway = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.DefaultGateway -ne $null }).DefaultGateway -join ", "
$DNS = (Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses -join ", "
$VPNConnections = (Get-VpnConnection | Select-Object -ExpandProperty Name) -join ", "
$FirewallStatus = (Get-NetFirewallProfile | ForEach-Object { "$($_.Name): $($_.Enabled)" }) -join ", "

# Software- und Peripheriegeräte
$OSVersion = (Get-ComputerInfo | Select-Object -ExpandProperty WindowsVersion)
$OSBuild = (Get-ComputerInfo | Select-Object -ExpandProperty WindowsBuildLabEx)
$InstalledSoftware = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion) | Out-String
$USBDevices = (Get-PnpDevice | Where-Object { $_.Class -eq 'USB' } | Select-Object -ExpandProperty FriendlyName) -join ", "
$Monitors = (Get-CimInstance -ClassName Win32_DesktopMonitor | ForEach-Object { "Name: $($_.Name), Auflösung: $($_.ScreenWidth)x$($_.ScreenHeight)" }) -join ", "

# Speicherpfad definieren
if ($env:SESSIONNAME -match "^ICA") {
    $OutputPath = "-"
} else {
    $OutputPath = "$env:USERPROFILE\Desktop\SupportInfo.txt"
}

# Informationen zusammenstellen
$SupportInfo = @"
Ausführungsdatum: $ExecutionDate
Skriptversion: $ScriptVersion

Benutzername: $UserName
Rechnername: $ComputerName
IP-Adressen: $IPAddresses

Hardware:
CPU: $CPU
RAM: $RAM GB
Grafikkarte(n): $GPU
Mainboard: $Mainboard
BIOS-Version: $BIOS

Netzwerk:
MAC-Adressen: $MACAddresses
Standardgateway: $Gateway
DNS-Server: $DNS
VPN-Verbindungen: $VPNConnections
Firewall-Status: $FirewallStatus

Software:
Betriebssystem: $OSVersion (Build $OSBuild)
Installierte Software:
$InstalledSoftware

Peripheriegeräte:
USB-Geräte: $USBDevices
Monitore: $Monitors

Kerberos-Tickets:
$KlistOutput

Laufwerke:
$DrivesInfo
"@

# Ausgabe in eine Datei speichern
$SupportInfo | Set-Content -Path $OutputPath -Encoding UTF8

# Benutzerbenachrichtigung
Write-Host "Support-Informationen wurden erfolgreich erstellt und gespeichert unter: $OutputPath"
