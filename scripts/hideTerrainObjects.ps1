# Build-time handling of the editor's "Hide Terrain Objects" modules (ModuleHideTerrainObjects_F). Such a module hides
# everything in its area at mission start and deletes itself, whatever map of the mode is played. For modes that pick
# the areas per map (the warfare library: SC\mapSetup.sqf, SC_fnc_hideTerrainAreas) the build takes the modules out
# of the STAGED mission.sqm and lists their areas in hideTerrainAreas.sqf at the mission root:
#   [[[x, y], a, b, direction, isRectangle, filter, hideLocally], ...]
# Never modifies the authoritative editor/source mission.sqm.

# Text of a staged mission.sqm (binarized ones are decoded with CfgConvert).
function Read-MissionSqm([string]$Path, [string]$CfgConvert) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    if (!($bytes.Length -gt 4 -and $bytes[0] -eq 0 -and $bytes[1] -eq 114)) {
        return [IO.File]::ReadAllText($Path)
    }
    if (!$CfgConvert -or !(Test-Path $CfgConvert)) {
        throw "binarized $Path needs CfgConvert (cfg\toolsPath.txt)"
    }
    $decoded = "$Path.decoded.txt"
    & $CfgConvert -txt -dst $decoded $Path | Out-Null
    if ($LASTEXITCODE -ne 0 -or !(Test-Path $decoded)) {
        throw "cannot decode $Path"
    }
    $text = [IO.File]::ReadAllText($decoded)
    Remove-Item -LiteralPath $decoded
    $text
}

# index of the '}' closing the '{' at $Open (quoted strings with "" escapes are skipped)
function Get-BlockEnd([string]$Text, [int]$Open) {
    $depth = 0
    $quoted = $false
    for ($i = $Open; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]
        if ($c -eq '"') {
            if ($quoted -and $i + 1 -lt $Text.Length -and $Text[$i + 1] -eq '"') {
                $i++
                continue
            }
            $quoted = !$quoted
            continue
        }
        if ($quoted) {
            continue
        }
        if ($c -eq '{') {
            $depth++
        } elseif ($c -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return $i
            }
        }
    }
    throw 'unbalanced braces in mission.sqm'
}

function Get-SqmNumbers([string]$Text, [string]$Name) {
    $m = [regex]::Match($Text, "\b$Name\[\]\s*=\s*\{([^}]*)\}")
    if (!$m.Success) {
        return @()
    }
    @($m.Groups[1].Value.Split(',') | ForEach-Object { [double]::Parse($_.Trim(), [Globalization.CultureInfo]::InvariantCulture) })
}

function Get-SqmAttributeValue([string]$Item, [string]$Property, $Default) {
    $m = [regex]::Match($Item, "property\s*=\s*""$([regex]::Escape($Property))"";[\s\S]*?\bvalue\s*=\s*([^;]+);")
    if ($m.Success) {
        $m.Groups[1].Value.Trim()
    } else {
        $Default
    }
}

# body of one "class Entities { ... }" without the modules (items renumbered); module areas are added to $Areas
function Remove-HideModules([string]$Body, [System.Collections.Generic.List[string]]$Areas) {
    $kept = New-Object System.Collections.Generic.List[string]
    $pos = 0
    $head = [regex]::new('\bclass\s+Item\d+\s*\{')
    while ($true) {
        $m = $head.Match($Body, $pos)
        if (!$m.Success) {
            break
        }
        $end = Get-BlockEnd $Body ($m.Index + $m.Length - 1)
        $semicolon = $Body.IndexOf(';', $end)
        $item = $Body.Substring($m.Index, $semicolon + 1 - $m.Index)
        $pos = $semicolon + 1
        $inner = $item.Substring($m.Length, $end - $m.Index - $m.Length)
        $nested = [regex]::Match($inner, '\bclass\s+Entities\s*\{')
        if ($nested.Success) {
            $open = $m.Length + $nested.Index + $nested.Length - 1
            $close = Get-BlockEnd $item $open
            $item = $item.Substring(0, $open + 1) + (Remove-HideModules $item.Substring($open + 1, $close - $open - 1) $Areas) + $item.Substring($close)
            $kept.Add($item)
            continue
        }
        if ($inner -notmatch '(?m)^\s*type\s*=\s*"ModuleHideTerrainObjects_F"\s*;') {
            $kept.Add($item)
            continue
        }

        # Eden positions are [x, height, y], rotations in radians
        $position = Get-SqmNumbers $inner 'position'
        $angles = Get-SqmNumbers $inner 'angles'
        $size = Get-SqmNumbers $inner 'areaSize'
        $direction = if ($angles.Count -ge 2) {
            $angles[1] * 180 / [Math]::PI
        } else {
            0
        }
        $rectangle = if ($inner -match '\bareaIsRectangle\s*=\s*1\s*;') {
            'true'
        } else {
            'false'
        }
        $filter = Get-SqmAttributeValue $inner '#filter' '0'
        $hideLocally = if ((Get-SqmAttributeValue $inner '#hideLocally' '0') -eq '1') {
            'true'
        } else {
            'false'
        }
        $inv = [Globalization.CultureInfo]::InvariantCulture
        $Areas.Add(('[[{0},{1}],{2},{3},{4},{5},{6},{7}]' -f $position[0].ToString($inv), $position[2].ToString($inv),
                $size[0].ToString($inv), $size[2].ToString($inv), [Math]::Round($direction, 3).ToString($inv), $rectangle, $filter, $hideLocally))
    }
    $items = for ($i = 0; $i -lt $kept.Count; $i++) {
        [regex]::Replace($kept[$i], '^class\s+Item\d+', "class Item$i")
    }
    "`r`nitems=$($kept.Count);`r`n" + ($items -join "`r`n") + "`r`n"
}

function Convert-HideTerrainModules([string]$MissionPath, [string]$CfgConvert) {
    $path = Join-Path $MissionPath 'mission.sqm'
    $text = Read-MissionSqm $path $CfgConvert
    $areas = New-Object System.Collections.Generic.List[string]
    $mission = [regex]::Match($text, '\bclass\s+Mission\s*\{')
    if (!$mission.Success) {
        throw 'Mission class missing in staged SQM'
    }
    $entities = [regex]::Match($text.Substring($mission.Index), '\bclass\s+Entities\s*\{')
    if ($entities.Success) {
        $open = $mission.Index + $entities.Index + $entities.Length - 1
        $close = Get-BlockEnd $text $open
        $body = Remove-HideModules $text.Substring($open + 1, $close - $open - 1) $areas
        if ($areas.Count -gt 0) {
            $text = $text.Substring(0, $open + 1) + $body + $text.Substring($close)
            [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
        }
    }
    $list = if ($areas.Count) {
        "`r`n    " + ($areas -join ",`r`n    ") + "`r`n"
    } else {
        ''
    }
    $content = "// generated by scripts\hideTerrainObjects.ps1 from the Hide Terrain Objects modules of mission.sqm:`r`n" +
    "// [[x, y], a, b, direction, isRectangle, filter, hideLocally]`r`n[$list]`r`n"
    [IO.File]::WriteAllText((Join-Path $MissionPath 'hideTerrainAreas.sqf'), $content, (New-Object Text.UTF8Encoding($false)))
    $areas.Count
}
