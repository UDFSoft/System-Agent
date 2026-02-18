# Copyright 2025 UDFSOFT
# Licensed under the Apache License, Version 2.0
# More details: https://smart.udfsoft.com/

$ErrorActionPreference = "Stop"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# =====================
# CONFIG
# =====================

$URL_BASE = "https://smart.udfsoft.com/api/v1/devices/commands".Trim()
$COMMAND_URL = $URL_BASE
$SEND_URL    = $URL_BASE
$API_KEY     = "xxxxxx".Trim()

# =====================
# DEVICE ID (Windows)
# =====================
try {
    $DEVICE_ID = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography").MachineGuid
} catch {
    Write-Error "Cannot read MachineGuid"
    exit 1
}

Write-Host ""
Write-Host " =========================================== "
Write-Host "|                                           |"
Write-Host "|  Welcome to the world of udfsoft.com !    |"
Write-Host "|                                           |"
Write-Host "|  If you have any questions about the      |"
Write-Host "|  service or would like to obtain an API   |"
Write-Host "|  key, please contact support@udfsoft.com  |"
Write-Host "|                                           |"
Write-Host " =========================================== "
Write-Host ""
Write-Host "  DEVICE_ID: $DEVICE_ID"
Write-Host ""

# =====================
# GET COMMAND
# =====================
Write-Host "[INFO] Requesting command..."
$escapedDeviceId = [System.Uri]::EscapeDataString($DEVICE_ID)

$commandUrl = "${COMMAND_URL}?device_id=${escapedDeviceId}"

$commandCurlArgs = @(
  "-s"
  "--url", $commandUrl
  "-H", "Content-Type: application/json"
  "-H", "X-DEVICE-ID: $DEVICE_ID"
  "-H", "X-Api-Key: $API_KEY"
  "-H", "X-Platform: windows"
)

Write-Host "  commandCurlArgs: $commandCurlArgs"


$commandResponseRaw = & curl.exe @commandCurlArgs

if (-not $commandResponseRaw) {
    Write-Error "Empty response from server"
    exit 1
}

Write-Host "commandResponseRaw: $commandResponseRaw"

$commandResponse = $commandResponseRaw | ConvertFrom-Json
$COMMAND = $commandResponse.command


if ([string]::IsNullOrEmpty($COMMAND)) {
    Write-Host "[INFO] No command received"
    exit 0
}

Write-Host "[INFO] Command received: $COMMAND"

# =====================
# FUNCTIONS
# =====================

function Get-BaseInfo {
    $hostname = $env:COMPUTERNAME
    return "`nHOSTNAME: $hostname`n"
}

function Get-CpuInfo {
    Get-CimInstance Win32_Processor |
        Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed |
        Format-List | Out-String
}

function Get-RamInfo {
    Get-CimInstance Win32_OperatingSystem |
        Select-Object `
            @{n="TotalMemory(GB)";e={[math]::Round($_.TotalVisibleMemorySize/1MB,2)}},
            @{n="FreeMemory(GB)";e={[math]::Round($_.FreePhysicalMemory/1MB,2)}} |
        Format-List | Out-String
}

function Get-DiskInfo {
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
        Select-Object DeviceID,
            @{n="Size(GB)";e={[math]::Round($_.Size/1GB,2)}},
            @{n="Free(GB)";e={[math]::Round($_.FreeSpace/1GB,2)}} |
        Format-Table | Out-String
}

function Get-BatteryInfo {
    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    if (-not $battery) {
        return "No battery detected"
    }

    @"
BAT_PERCENT: $($battery.EstimatedChargeRemaining)
BAT_STATUS:  $($battery.BatteryStatus)
"@
}

function Get-SensorsInfo {
    return "Sensors utility not available on Windows"
}

# =====================
# EXECUTE COMMAND
# =====================

$DATA = ""

Get-BaseInfo | Out-Host

Write-Host "COMMAND: $COMMAND"

switch ($COMMAND) {

    "NO_COMMAND" {
        exit 0
    }

    "SEND_CPU_INFO" {
        $DATA = Get-CpuInfo
    }

    "SEND_SENSORS_INFO" {
        $DATA = Get-SensorsInfo # Not working 
    }

    "SEND_RAM_INFO" {
        $DATA = Get-RamInfo
    }

    "SEND_DISK_INFO" {
        $DATA = Get-DiskInfo
    }

    "SEND_BATTERY_INFO" {
        $DATA = Get-BatteryInfo
    }

    "SEND_ALL_INFO" {
        $DATA = @"
CPU:
$(Get-CpuInfo)

SENSORS:
$(Get-SensorsInfo)

RAM:
$(Get-RamInfo)

DISK:
$(Get-DiskInfo)

BATTERY:
$(Get-BatteryInfo)
"@
    }

    default {
        Write-Warning "[WARN] Unknown command: $COMMAND"
        exit 1
    }
}

if ([string]::IsNullOrEmpty($DATA)) {
    $DATA = "No data available"
}

# =====================
# SEND DATA
# =====================
Write-Host "[INFO] Sending data..."

$sendUrl = "${SEND_URL}/${COMMAND}"

Write-Host "sendUrl: $sendUrl"

$sendCurlArgs = @(
  "-s"
  "-X", "POST"
  "--url", $sendUrl
  "-H", "Content-Type: text/plain; charset=utf-8"
  "-H", "X-DEVICE-ID: $DEVICE_ID"
  "-H", "X-Api-Key: $API_KEY"
  "-H", "X-Platform: windows"
  "--data-binary", $DATA
)

# Write-Host "  commandCurlArgs: $sendCurlArgs"


$sendResponseRaw = & curl.exe @sendCurlArgs

Write-Host "sendResponseRaw: $sendResponseRaw"

Write-Host "[INFO] Done."
