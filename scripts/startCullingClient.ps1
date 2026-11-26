param(
    [Parameter(Mandatory = $true)][string]$Template,
    [int]$ServerProcessId = 0,
    [switch]$Detach
)

$ErrorActionPreference = 'Stop'

function Get-CullingRecoveryReason {
    param(
        [string[]]$ServerTail,
        [string[]]$WorkerTail
    )
    $status = @($ServerTail | Select-String 'CULLING\|SERVER\|') | Select-Object -Last 1
    if (!$status -or $status.Line -notmatch '\|worker=-1\|') {
        return ''
    }
    $mission = @($WorkerTail | Select-String 'Mission file:') | Select-Object -Last 1
    if ($mission -and $mission.Line -match 'Mission file:\s*intro') {
        return 'disconnected into intro mission'
    }
    return 'unregistered'
}

# ---- launch ----

$root = Split-Path $PSScriptRoot -Parent
if ($Template -notmatch '^[A-Za-z0-9_-]+$') {
    throw 'Invalid template name'
}
if ($Detach) {
    $launch = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Template', $Template)
    if ($ServerProcessId) {
        $launch += @('-ServerProcessId', "$ServerProcessId")
    }
    $startup = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ ShowWindow = [uint16]0 }
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = ('powershell ' + ($launch -join ' '))
        ProcessStartupInformation = $startup
    } | Out-Null
    return
}

$folder = Join-Path $root "templates\$Template"
$server = (Get-Content (Join-Path $root 'cfg\serverPath.txt') -First 1).Trim()
$port = [int](Get-Content (Join-Path $folder 'port.txt') -First 1)
$name = "culling_$Template"
if (Get-CimInstance Win32_Process -Filter "Name='arma3server_x64.exe'" | Where-Object { $_.CommandLine -match ('-name=' + [regex]::Escape($name) + '(?:\s|$)') }) {
    return
}
if (!$ServerProcessId) {
    $until = (Get-Date).AddSeconds(60)
    do {
        $endpoint = Get-NetUDPEndpoint -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($endpoint) {
            $ServerProcessId = $endpoint.OwningProcess
            break
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $until)
}
$hostProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$ServerProcessId"
if (!$hostProcess -or $hostProcess.Name -ne 'arma3server_x64.exe' -or $hostProcess.CommandLine -notlike "*$Template*server.cfg*") {
    throw 'Matching play server not found'
}

# ---- client configuration ----

$profile = Join-Path $folder 'culling_profiles'
New-Item -ItemType Directory -Force $profile | Out-Null
$cfg = [IO.File]::ReadAllText((Join-Path $folder 'server.cfg'))
$password = [regex]::Match($cfg, '(?m)^\s*password\s*=\s*"([^"]*)"').Groups[1].Value
$mods = @()
if (Test-Path (Join-Path $folder 'mods.txt')) {
    $workshop = (Get-Content (Join-Path $root 'cfg\workshopModsPath.txt') -First 1).Trim()
    $mods += @(Get-Content (Join-Path $folder 'mods.txt') | Where-Object { $_ -and $_ -notmatch '^\s*//' } | ForEach-Object { Join-Path $workshop $_.Trim() })
}
if (Test-Path (Join-Path $folder 'modsOfficial.txt')) {
    $mods += @(Get-Content (Join-Path $folder 'modsOfficial.txt') | Where-Object { $_ -and $_ -notmatch '^\s*//' })
}
if (Test-Path (Join-Path $folder 'clientMods.txt')) {
    $mods += @(Get-Content (Join-Path $folder 'clientMods.txt') | Where-Object { $_ -and $_ -notmatch '^\s*//' } | ForEach-Object { Join-Path $root "build\mods\$($_.Trim())" } | Where-Object { Test-Path (Join-Path $_ 'addons') })
}

# ---- client supervision ----

$hc = $null
$unregisteredSince = $null
try {
    while (Get-Process -Id $ServerProcessId -ErrorAction SilentlyContinue) {
        if (!$hc -or $hc.HasExited) {
            $args = @('-client', '-connect=127.0.0.1', "-port=$port", "-name=$name", '-nosound', '-world=empty', "`"-profiles=$profile`"", "`"-password=$password`"")
            if ($mods.Count) {
                $args += "`"-mod=$($mods -join ';')`""
            }
            $hc = Start-Process (Join-Path $server 'arma3server_x64.exe') -ArgumentList $args -WorkingDirectory $server -WindowStyle Normal -PassThru
            $unregisteredSince = $null
        } else {
            $serverLog = Get-ChildItem (Join-Path $folder 'tmp_profiles') -Filter *.rpt | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $workerLog = Get-ChildItem $profile -Filter *.rpt | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $reason = if ($serverLog -and $workerLog) {
                Get-CullingRecoveryReason (Get-Content $serverLog.FullName -Tail 150) (Get-Content $workerLog.FullName -Tail 80)
            } else {
                ''
            }
            if ($reason) {
                if (!$unregisteredSince) {
                    $unregisteredSince = Get-Date
                }
                if ($reason -ne 'unregistered' -or ((Get-Date) - $unregisteredSince).TotalSeconds -ge 30) {
                    Add-Content (Join-Path $profile 'supervisor.log') "$(Get-Date -Format o) Reconnecting HC: $reason"
                    Stop-Process -Id $hc.Id -Force
                    $hc.WaitForExit()
                    $hc = $null
                    $unregisteredSince = $null
                }
            } else {
                $unregisteredSince = $null
            }
        }
        Start-Sleep -Seconds 5
    }
} finally {
    if ($hc -and !$hc.HasExited) {
        Stop-Process -Id $hc.Id -Force
        $hc.WaitForExit()
    }
}
