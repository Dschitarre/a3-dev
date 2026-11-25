<#
.SYNOPSIS
    Builds the mission PBOs (src\gameModes) and mod PBOs (src\mods).

.DESCRIPTION
    Mission build (one PBO per game mode and map, output: build\mpmissions or build\missions):
      1. copy src\gameModes\<gameMode> without cfg\ and missionFiles\
      2. mission.sqm      <- missionFiles\mission<map>.sqm
      3. variant configs  <- for each line "<dir>\<name>.hpp" in cfg\variantConfigs.txt the file is replaced by
                             <name><mapGroup>.hpp (cfg\mapGroups.txt: "<map>=<group>") or <name><map>.hpp
      4. shared libs      <- for each line "<lib>|<target>" in cfg\sharedLibs.txt: src\shared\<lib> -> <target>
      5. integrated mods  <- for each mod in cfg\modsIntegrated.txt: src\mods\<mod>\addons\<mod>\scripts
                             -> modsIntegrated\<mod>\scripts (without fn_init.sqf), plus generated modsIntegrated\modList.sqf
      6. unpacked copy into the client profile (cfg\clientProfilePath.txt) for the editor, then AddonBuilder + sign

    Mod build (output: build\mods\<mod>\addons\<mod>.pbo + key).

    Everything is staged first (so config errors stop the build before anything is packed),
    then all PBOs are packed in parallel. AddonBuilder logs: build\logs\<name>.log

.EXAMPLE
    build.ps1 -All                                  # all mods and all missions
    build.ps1 -Mods                                 # all mods
    build.ps1 -Mod killfeed,jump                    # selected mods
    build.ps1 -Missions                             # every map of every game mode
    build.ps1 -GameMode sectorControl               # every map of one game mode
    build.ps1 -GameMode sectorControl -Map Altis    # one mission
    build.ps1 -Template sectorControlAltis          # game mode and maps of templates\<name>
    build.ps1 -Missions -StageOnly                  # only assemble the mission folders in build\stage (no packing)
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$All,
    [switch]$Mods,
    [string[]]$Mod,
    [switch]$Missions,
    [string]$GameMode,
    [string[]]$Map,
    [string]$Template,
    [switch]$StageOnly
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'culling.ps1')
. (Join-Path $PSScriptRoot 'hideTerrainObjects.ps1')
. (Join-Path $PSScriptRoot 'playableSlots.ps1')

# ---- helpers ----

# Non-empty, non-comment lines of a list file (missing file = empty list).
function Read-List([string]$Path) {
    if (-not (Test-Path $Path)) {
        return @()
    }
    @(Get-Content $Path | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("//") })
}

# First line of cfg\<Name>.txt.
function Read-Cfg([string]$Name, [switch]$Optional) {
    $path = Join-Path $Root "cfg\$Name.txt"
    if (Test-Path $path) {
        return (Read-List $path | Select-Object -First 1)
    }
    if (-not $Optional) {
        throw "missing config file $path"
    }
}

# Deletes a folder, retrying a few times: on synced drives (Google Drive) files can stay locked for a moment
# after another process (AddonBuilder, the sync client) touched them.
function Remove-Directory([string]$Path, [switch]$WarnOnly) {
    for ($attempt = 1; Test-Path $Path; $attempt++) {
        try {
            Remove-Item $Path -Recurse -Force -ErrorAction Stop
        } catch {
            if ($attempt -lt 10) {
                Start-Sleep -Milliseconds (300 * $attempt)
                continue
            }
            if ($WarnOnly) {
                Write-Warning "could not delete $Path ($($_.Exception.Message))"
                return
            }
            throw
        }
    }
}

function Reset-Directory([string]$Path) {
    Remove-Directory $Path
    New-Item -ItemType Directory -Force $Path | Out-Null
}

function Get-AddonBuilder {
    $candidates = @()
    $toolsPath = Read-Cfg toolsPath -Optional
    if ($toolsPath) {
        $candidates += $toolsPath
    }
    $steamCmdPath = Read-Cfg steamCmdPath -Optional
    if ($steamCmdPath) {
        $candidates += Join-Path $steamCmdPath "steamapps\common\Arma 3 Tools"
    }

    foreach ($dir in $candidates) {
        $exe = Join-Path $dir "AddonBuilder\AddonBuilder.exe"
        if (Test-Path $exe) {
            return $exe
        }
    }
    throw "AddonBuilder.exe not found in: $($candidates -join ', '). Fix cfg\toolsPath.txt or run 'scripts\update.bat tools'."
}

# CfgConvert.exe of the Arma 3 Tools (cfg\toolsPath.txt or the steamcmd install); $null if there is none
function Get-CfgConvert {
    $steamCmdPath = Read-Cfg steamCmdPath -Optional
    $candidates = @((Read-Cfg toolsPath -Optional))
    if ($steamCmdPath) {
        $candidates += Join-Path $steamCmdPath "steamapps\common\Arma 3 Tools"
    }

    foreach ($dir in ($candidates | Where-Object { $_ })) {
        $exe = Join-Path $dir "CfgConvert\CfgConvert.exe"
        if (Test-Path $exe) {
            return $exe
        }
    }
    $null
}

# A staged folder that AddonBuilder packs into <Destination>\<folder name>.pbo.
function New-PackJob([string]$Source, [string]$Destination) {
    $name = Split-Path $Source -Leaf
    [pscustomobject]@{
        Name = $name
        Source = $Source
        Destination = $Destination
        Pbo = Join-Path $Destination "$name.pbo"
        Log = Join-Path $Root "build\logs\$name.log"
        Process = $null
    }
}

function Start-PackJob($Job) {
    New-Item -ItemType Directory -Force (Split-Path $Job.Log -Parent), $Job.Destination | Out-Null
    Remove-Item $Job.Pbo, "$($Job.Pbo).*.bisign" -Force -ErrorAction SilentlyContinue

    $arguments = @(
        "`"$($Job.Source)`"",
        "`"$($Job.Destination)`"",
        "`"-include=$Root\cfg\include.lst`"",
        "`"-sign=$Root\cfg\keys\$script:KeyName.biprivatekey`"",
        "`"-temp=$Root\build\tmp\$($Job.Name)`"", # own temp folder per PBO, so parallel builds don't clear each other's files
        # without it AddonBuilder asks the Steam client for the tools folder and fails when Steam is not running
        "`"-toolsDirectory=$(Split-Path (Split-Path $script:AddonBuilder -Parent) -Parent)`"",
        "-clear"
    )
    $Job.Process = Start-Process $script:AddonBuilder -ArgumentList $arguments -NoNewWindow -PassThru `
        -RedirectStandardOutput $Job.Log -RedirectStandardError ($Job.Log -replace "\.log$", ".err.log")
}

# Packs all jobs, at most $Throttle at a time. A job failed if its PBO is missing (AddonBuilder's exit code is not reliable).
function Invoke-PackJobs($Jobs, [int]$Throttle) {
    $queue = New-Object System.Collections.Queue (, @($Jobs))
    $running = New-Object System.Collections.ArrayList
    $failed = @()

    while ($queue.Count -or $running.Count) {
        while ($queue.Count -and $running.Count -lt $Throttle) {
            $job = $queue.Dequeue()
            Start-PackJob $job
            [void]$running.Add($job)
        }

        Start-Sleep -Milliseconds 200

        foreach ($job in @($running | Where-Object { $_.Process.HasExited })) {
            $running.Remove($job)
            if (Test-Path $job.Pbo) {
                Write-Host "  packed $($job.Name).pbo"
                Remove-Directory $job.Source -WarnOnly   # staging folder is only needed for packing
            } else {
                $failed += $job.Name
                Write-Host "  FAILED $($job.Name) (log: $($job.Log))" -ForegroundColor Red
                Get-Content $job.Log -Tail 15 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" }
            }
        }
    }
    $failed
}

# ---- missions ----

function Copy-VariantConfigs([string]$GameModePath, [string]$MissionPath, [string]$MapName) {
    $mapGroup = $null
    foreach ($line in Read-List (Join-Path $GameModePath "cfg\mapGroups.txt")) {
        $key, $value = $line -split "=", 2
        if ($key.Trim() -ieq $MapName) {
            $mapGroup = $value.Trim()
        }
    }

    foreach ($relativePath in Read-List (Join-Path $GameModePath "cfg\variantConfigs.txt")) {
        $dir = Split-Path $relativePath -Parent
        $name = [IO.Path]::GetFileNameWithoutExtension($relativePath)
        $ext = [IO.Path]::GetExtension($relativePath)
        $sourceDir = Join-Path $GameModePath $dir
        $missionDir = Join-Path $MissionPath $dir
        $default = Join-Path $missionDir "$name$ext"

        # A shared framework owns its variants too; mode-specific source files can still override them.
        if (-not (Test-Path $sourceDir)) {
            foreach ($line in Read-List (Join-Path $GameModePath "cfg\sharedLibs.txt")) {
                $lib, $target = ($line -split "\|", 2) | ForEach-Object { $_.Trim() }
                if ($dir -eq $target -or $dir.StartsWith($target + "\")) {
                    $suffix = $dir.Substring($target.Length).TrimStart('\')
                    $sourceDir = Join-Path (Join-Path $Root "src\shared\$lib") $suffix
                    break
                }
            }
        }

        $variant = @($mapGroup, $MapName) | Where-Object { $_ } |
            ForEach-Object { Join-Path $sourceDir "$name$_$ext" } | Where-Object { Test-Path $_ } | Select-Object -First 1

        if (-not $variant -and -not (Test-Path $default)) {
            throw "${relativePath}: neither a variant for map '$MapName' (group '$mapGroup') nor a default file exists"
        }

        # the PBO only gets <name><ext>: drop all variants (and the default, if a variant replaces it)
        Get-ChildItem $missionDir -Filter "$name*$ext" -File |
            Where-Object { $variant -or ($_.Name -ne "$name$ext") } | Remove-Item -Force

        if ($variant) {
            Copy-Item $variant $default
            Write-Host "  variant  $relativePath <= $(Split-Path $variant -Leaf)"
        }
    }
}

function Copy-SharedLibs([string]$GameModePath, [string]$MissionPath) {
    foreach ($line in Read-List (Join-Path $GameModePath "cfg\sharedLibs.txt")) {
        $lib, $target = ($line -split "\|", 2) | ForEach-Object { $_.Trim() }
        $source = Join-Path $Root "src\shared\$lib"
        if (-not (Test-Path $source)) {
            throw "shared lib '$lib' not found ($source)"
        }

        $destination = Join-Path $MissionPath $target
        New-Item -ItemType Directory -Force $destination | Out-Null
        Copy-Item "$source\*" $destination -Recurse -Force
        Write-Host "  shared   $lib -> $target"
    }
}

function Copy-IntegratedMods([string]$GameModePath, [string]$MissionPath) {
    $modsDir = Join-Path $MissionPath "modsIntegrated"
    New-Item -ItemType Directory -Force $modsDir | Out-Null
    $modNames = @(Read-List (Join-Path $GameModePath "cfg\modsIntegrated.txt") | Select-Object -Unique)

    foreach ($modName in $modNames) {
        $source = Join-Path $Root "src\mods\$modName\addons\$modName\scripts"
        if (-not (Test-Path $source)) {
            throw "integrated mod '$modName' not found ($source)"
        }

        $destination = Join-Path $modsDir "$modName\scripts"
        New-Item -ItemType Directory -Force $destination | Out-Null
        Copy-Item "$source\*" $destination -Recurse -Force
        Remove-Item (Join-Path $destination "fn_init.sqf") -Force -ErrorAction SilentlyContinue
    }

    $list = ($modNames | ForEach-Object { "    `"$_`"" }) -join ",`r`n"
    $content = "// generated by scripts\build.ps1 from cfg\modsIntegrated.txt, read by modsIntegrated\loadMods.sqf`r`n[`r`n$list`r`n]`r`n"
    Set-Content (Join-Path $modsDir "modList.sqf") $content -Encoding ASCII -NoNewline
    Write-Host "  mods     $($modNames -join ', ')"
}

function Build-Mission([string]$GameModeName, [string]$MapName) {
    $gameModePath = Join-Path $Root "src\gameModes\$GameModeName"
    if (-not (Test-Path $gameModePath)) {
        throw "game mode '$GameModeName' not found"
    }

    $isMultiplayer = (Read-List (Join-Path $gameModePath "cfg\isMultiplayer.txt")) -contains "true"
    $missionFolder = if ($isMultiplayer) {
        "mpmissions"
    } else {
        "missions"
    }
    $missionName = "$GameModeName.$MapName"
    $outputDir = Join-Path $Root "build\$missionFolder"
    $missionPath = if ($StageOnly) {
        Join-Path $Root "build\stage\$missionFolder\$missionName"
    } else {
        Join-Path $outputDir $missionName
    }

    Write-Host "mission $missionName"
    Reset-Directory $missionPath

    Get-ChildItem $gameModePath -Force | Where-Object { $_.Name -notin @("cfg", "missionFiles") } |
        Copy-Item -Destination $missionPath -Recurse -Force

    $sqm = Join-Path $gameModePath "missionFiles\mission$MapName.sqm"
    if (-not (Test-Path $sqm)) {
        throw "missing $sqm"
    }
    Copy-Item $sqm (Join-Path $missionPath "mission.sqm")

    Copy-SharedLibs $gameModePath $missionPath
    Copy-VariantConfigs $gameModePath $missionPath $MapName
    Copy-IntegratedMods $gameModePath $missionPath

    # Hide Terrain Objects modules become per-map areas where the warfare library applies them
    # (scripts\hideTerrainObjects.ps1, SC_fnc_hideTerrainAreas)
    if (Test-Path (Join-Path $missionPath 'SC\mapSetup.sqf')) {
        $hidden = Convert-HideTerrainModules $missionPath (Get-CfgConvert)
        Write-Host "  hide terrain areas: $hidden"
    }

    # playable units per side (scripts\playableSlots.ps1): only with the mode's cfg\playableSlots.txt
    $playableSlots = Read-List (Join-Path $gameModePath 'cfg\playableSlots.txt') | Select-Object -First 1
    if ($playableSlots) {
        $added = Add-PlayableSlots $missionPath (Get-CfgConvert) ([int]$playableSlots)
        Write-Host "  playable slots per side: $playableSlots (added $(($added.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', '))"
    }

    # dedicated culling HC (scripts\culling.ps1): only with cfg\cullingHC.txt = true
    if ($isMultiplayer -and (Read-Cfg cullingHC -Optional) -eq 'true') {
        Add-CullingSlot $missionPath (Get-CfgConvert)
    }

    if ($StageOnly) {
        return $null
    }

    $clientProfilePath = Read-Cfg clientProfilePath -Optional
    if ($clientProfilePath) {
        $profileCopy = Join-Path $clientProfilePath "$missionFolder\$missionName"
        Remove-Directory $profileCopy
        Copy-Item $missionPath $profileCopy -Recurse
    }

    New-PackJob $missionPath $outputDir
}

# ---- mods ----

function Build-Mod([string]$ModName) {
    $source = Join-Path $Root "src\mods\$ModName"
    if (-not (Test-Path (Join-Path $source "addons\$ModName"))) {
        throw "mod '$ModName' not found ($source\addons\$ModName)"
    }

    Write-Host "mod $ModName"
    $modPath = Join-Path $Root "build\mods\$ModName"
    Remove-Directory $modPath
    Copy-Item $source $modPath -Recurse
    Copy-Item (Join-Path $Root "cfg\keys\$script:KeyName.bikey") $modPath

    New-PackJob (Join-Path $modPath "addons\$ModName") (Join-Path $modPath "addons")
}

# ---- main ----

# "-Mod a,b" arrives as one string when called via "powershell -File"
function Split-Names([string[]]$Names) {
    @($Names | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
$Mod = Split-Names $Mod
$Map = Split-Names $Map

$modNames = @()
$missionList = @()   # entries: @(gameMode, map)

if ($All -or $Mods) {
    $modNames += (Get-ChildItem (Join-Path $Root "src\mods") -Directory).Name
}
if ($Mod) {
    $modNames += $Mod
}

if ($All -or $Missions) {
    foreach ($dir in Get-ChildItem (Join-Path $Root "src\gameModes") -Directory) {
        foreach ($m in Read-List (Join-Path $dir.FullName "cfg\maps.txt")) {
            $missionList += , @($dir.Name, $m)
        }
    }
}

if ($GameMode) {
    $maps = if ($Map) {
        $Map
    } else {
        Read-List (Join-Path $Root "src\gameModes\$GameMode\cfg\maps.txt")
    }
    foreach ($m in $maps) {
        $missionList += , @($GameMode, $m)
    }
}

if ($Template) {
    $templatePath = Join-Path $Root "templates\$Template"
    if (-not (Test-Path $templatePath)) {
        throw "template '$Template' not found"
    }
    $templateGameMode = Read-List (Join-Path $templatePath "gameMode.txt") | Select-Object -First 1
    foreach ($m in Read-List (Join-Path $templatePath "maps.txt")) {
        $missionList += , @($templateGameMode, $m)
    }
}

if (-not $modNames -and -not $missionList) {
    Get-Help $PSCommandPath -Examples
    exit 1
}

if ($StageOnly -and $modNames) {
    throw "-StageOnly only applies to missions"
}

$script:KeyName = Read-Cfg keyName
if (-not $StageOnly) {
    $script:AddonBuilder = Get-AddonBuilder
}

$startTime = Get-Date
$jobs = @()
foreach ($m in ($modNames | Select-Object -Unique)) {
    $jobs += Build-Mod $m
}
foreach ($mission in $missionList) {
    $job = Build-Mission $mission[0] $mission[1]
    if ($job) {
        $jobs += $job
    }
}

if ($StageOnly) {
    Write-Host "staged $($missionList.Count) mission(s) in build\stage"
    exit 0
}

$throttle = [Math]::Max(2, [Environment]::ProcessorCount / 2)
Write-Host "packing $($jobs.Count) PBO(s), $throttle in parallel ..."
$failed = @(Invoke-PackJobs $jobs $throttle)

$duration = [int]((Get-Date) - $startTime).TotalSeconds
if ($failed) {
    Write-Host "$($failed.Count) of $($jobs.Count) PBO(s) failed: $($failed -join ', ') (${duration}s)" -ForegroundColor Red
    exit 1
}
Write-Host "built $($jobs.Count) PBO(s) in ${duration}s" -ForegroundColor Green
