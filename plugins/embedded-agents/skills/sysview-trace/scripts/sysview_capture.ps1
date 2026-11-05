<#
.SYNOPSIS
    Record a SEGGER SystemView trace over JTAG into one .SVDat file (all cores).

.DESCRIPTION
    Run from the project root in a PowerShell where the ESP-IDF environment is
    active (idf.py and openocd on PATH).
    1. Builds the trace folder (-BuildDir) from -Defaults (unless -NoFlash).
    2. Flashes it over the USB-UART port (-Port).
    3. Starts OpenOCD with -OpenOcdCfg and records -Seconds of trace with
       `esp sysview_mcore` through OpenOCD's Tcl port (6666).
    4. Stops OpenOCD. Open the file in SystemView with File > Load Data
       (SystemView ignores a file given on its command line).

.EXAMPLE
    .\tools\sysview_capture.ps1 -Port COM5 -Seconds 5 -BuildDir build_trace `
        -Defaults "sdkconfig.defaults;sdkconfig.sysview_jtag" -OpenOcdCfg board/esp32s3-builtin.cfg
#>
param(
    [string]$Port = "COM5",
    [int]$Seconds = 5,
    [string]$BuildDir = "build_trace",
    [string]$Defaults = "sdkconfig.sysview_jtag",
    [string]$OpenOcdCfg = "board/esp32s3-builtin.cfg",
    [string]$Out = "",
    [switch]$NoFlash
)
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
if (-not (Get-Command idf.py -ErrorAction SilentlyContinue) -or -not (Get-Command openocd -ErrorAction SilentlyContinue)) {
    throw "Activate the ESP-IDF environment first (idf.py and openocd must be on PATH)."
}
if (-not $Out) { $Out = "$BuildDir/trace.SVDat" }

# Every idf.py call for the trace folder needs both -D options, otherwise
# idf.py falls back to the root sdkconfig (the normal firmware).
$idfArgs = @("-B", $BuildDir, "-D", "SDKCONFIG=$BuildDir/sdkconfig", "-D", "SDKCONFIG_DEFAULTS=$Defaults")
if (-not $NoFlash) {
    idf.py @idfArgs build
    if ($LASTEXITCODE -ne 0) { idf.py @idfArgs build }   # 1st run downloads esp_sysview and asks for a re-run
    if ($LASTEXITCODE -ne 0) { throw "build failed" }
    idf.py @idfArgs -p $Port flash
    if ($LASTEXITCODE -ne 0) { throw "flash failed" }
    # The reset after flashing also drops a native-USB JTAG link for a moment.
    Start-Sleep -Seconds 3
}

$outAbs = [IO.Path]::GetFullPath((Join-Path $root $Out)).Replace('\', '/')
New-Item -ItemType Directory -Force (Split-Path $outAbs) | Out-Null
Remove-Item $outAbs -ErrorAction SilentlyContinue
$ocdLog = Join-Path $root "$BuildDir/openocd.log"
$ocd = Start-Process openocd -ArgumentList "-f $OpenOcdCfg" -PassThru -NoNewWindow `
    -RedirectStandardError $ocdLog -RedirectStandardOutput "$ocdLog.out"

# OpenOCD Tcl RPC: command terminated by 0x1A, reply read up to 0x1A.
function Send-Ocd([System.Net.Sockets.NetworkStream]$s, [string]$cmd) {
    $bytes = [Text.Encoding]::ASCII.GetBytes($cmd + [char]0x1a)
    $s.Write($bytes, 0, $bytes.Length)
    $reply = New-Object System.Collections.Generic.List[byte]
    while ($true) {
        $b = $s.ReadByte()
        if ($b -lt 0 -or $b -eq 0x1a) { break }
        $reply.Add([byte]$b)
    }
    [Text.Encoding]::ASCII.GetString($reply.ToArray())
}

$client = $null
try {
    for ($i = 0; $i -lt 40 -and -not $client; $i++) {
        Start-Sleep -Milliseconds 250
        if ($ocd.HasExited) { throw "OpenOCD exited. See $ocdLog" }
        try { $client = New-Object System.Net.Sockets.TcpClient("127.0.0.1", 6666) } catch { $client = $null }
    }
    if (-not $client) { throw "Could not connect to OpenOCD on port 6666. See $ocdLog" }
    $s = $client.GetStream()
    # The app keeps running; on start SystemView receives the current task list.
    Write-Host (Send-Ocd $s "esp sysview_mcore start file://$outAbs")
    Write-Host "Recording $Seconds s of trace..."
    Start-Sleep -Seconds $Seconds
    Write-Host (Send-Ocd $s "esp sysview_mcore stop")
    Send-Ocd $s "shutdown" | Out-Null
}
finally {
    if ($client) { $client.Close() }
    if (-not $ocd.WaitForExit(5000)) { Stop-Process -Id $ocd.Id -Force }
}

if (Select-String -Path $ocdLog -Pattern "^Error|abort\(\) was called" -Quiet) {
    Write-Warning "OpenOCD log shows errors or a target abort:"
    Select-String -Path $ocdLog -Pattern "^Error|abort\(\) was called" | ForEach-Object { Write-Warning $_.Line }
}
if (-not (Test-Path $outAbs) -or (Get-Item $outAbs).Length -eq 0) {
    throw "No trace data written. See $ocdLog"
}
Write-Host ("Trace saved: {0} ({1:N0} bytes). In SystemView: File > Load Data." -f $outAbs, (Get-Item $outAbs).Length)
