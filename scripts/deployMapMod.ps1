<#
.SYNOPSIS
    Copies a built map mod (e.g. the Chernarus 2020 Base-Expansion terrain build) into build\mods\<Name> and signs its
    PBOs with the repo key, so templates can load it through clientMods.txt (server -mod, clients need the same mod).
.EXAMPLE
    deployMapMod.ps1 -Source C:\a3-localtest\tmp\dayz_surface\chernarus_dayz\@BR_Chernarus_DayZ_v10 -Name @Chernarus2020BaseExpansion
#>
param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Name
)
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$keyName = (Get-Content (Join-Path $Root "cfg\keyName.txt") -TotalCount 1).Trim()
$tools = (Get-Content (Join-Path $Root "cfg\toolsPath.txt") -TotalCount 1).Trim()
$sign = Join-Path $tools "DSSignFile\DSSignFile.exe"
if (-not (Test-Path (Join-Path $Source "addons"))) {
    throw "no addons folder in $Source"
}

$target = Join-Path $Root "build\mods\$Name"
if (Test-Path $target) {
    Remove-Item $target -Recurse -Force
}
New-Item -ItemType Directory -Force (Join-Path $target "addons"), (Join-Path $target "keys") | Out-Null
Copy-Item (Join-Path $Source "addons\*.pbo") (Join-Path $target "addons")
if (Test-Path (Join-Path $Source "mod.cpp")) {
    Copy-Item (Join-Path $Source "mod.cpp") $target
}
Copy-Item (Join-Path $Root "cfg\keys\$keyName.bikey") (Join-Path $target "keys")
foreach ($pbo in Get-ChildItem (Join-Path $target "addons") -Filter *.pbo) {
    & $sign (Join-Path $Root "cfg\keys\$keyName.biprivatekey") $pbo.FullName
    if (-not (Test-Path "$($pbo.FullName).$keyName.bisign")) {
        throw "signing failed: $($pbo.Name)"
    }
}
Set-Content (Join-Path $target "source.txt") $Source -Encoding ASCII
Write-Host "deployed $Source -> $target (signed with $keyName)"
