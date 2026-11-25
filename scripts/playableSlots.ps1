# Build-time playable slot fill. Never modifies the authoritative editor/source mission.sqm.
# A mode's cfg\playableSlots.txt (e.g. 67) is the number of playable units every side's group of playable units gets in
# the STAGED mission.sqm: the missing ones are copies of the group's last playable unit (same type and attributes, a
# bit beside it), so they show up in the lobby. A group that has as many already keeps its units. Uses Read-MissionSqm
# and Get-BlockEnd of scripts\hideTerrainObjects.ps1.

function Add-PlayableSlots([string]$MissionPath, [string]$CfgConvert, [int]$PerSide) {
    $path = Join-Path $MissionPath 'mission.sqm'
    $text = Read-MissionSqm $path $CfgConvert
    $nextId = 1 + ([regex]::Matches($text, '\bid\s*=\s*(\d+)\s*;') | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Maximum).Maximum
    $itemHead = [regex]::new('\bclass\s+Item\d+\s*\{')
    $added = @{}

    $mission = [regex]::Match($text, '\bclass\s+Mission\s*\{')
    $entities = [regex]::Match($text.Substring($mission.Index), '\bclass\s+Entities\s*\{')
    $open = $mission.Index + $entities.Index + $entities.Length - 1
    $close = Get-BlockEnd $text $open
    $pos = $open + 1

    # top-level groups of a side; edited from the back so earlier offsets stay valid
    $groups = @()
    while ($true) {
        $m = $itemHead.Match($text, $pos)
        if (!$m.Success -or $m.Index -ge $close) {
            break
        }
        $end = Get-BlockEnd $text ($m.Index + $m.Length - 1)
        $item = $text.Substring($m.Index, $end - $m.Index)
        $side = [regex]::Match($item, '^\s*side\s*=\s*"(\w+)"\s*;', 'Multiline')
        if ($item -match '\bdataType\s*=\s*"Group"' -and $side.Success -and $side.Groups[1].Value -in @('West', 'East', 'Independent')) {
            $groups += [pscustomobject]@{
                Start = $m.Index
                End = $end
                Side = $side.Groups[1].Value
            }
        }
        $pos = $end + 1
    }

    foreach ($group in ($groups | Sort-Object Start -Descending)) {
        $groupText = $text.Substring($group.Start, $group.End - $group.Start)
        $inner = [regex]::Match($groupText, '\bclass\s+Entities\s*\{')
        if (!$inner.Success) {
            continue
        }
        $bodyOpen = $inner.Index + $inner.Length - 1
        $bodyClose = Get-BlockEnd $groupText $bodyOpen
        $body = $groupText.Substring($bodyOpen + 1, $bodyClose - $bodyOpen - 1)

        $units = @()
        $p = 0
        while ($true) {
            $m = $itemHead.Match($body, $p)
            if (!$m.Success) {
                break
            }
            $end = Get-BlockEnd $body ($m.Index + $m.Length - 1)
            $semicolon = $body.IndexOf(';', $end)
            $units += $body.Substring($m.Index, $semicolon + 1 - $m.Index)
            $p = $semicolon + 1
        }

        $playable = @($units | Where-Object { $_ -match '\bisPlayable\s*=\s*1\s*;' })
        if ($playable.Count -eq 0 -or $playable.Count -ge $PerSide) {
            continue
        }

        $template = $playable[-1] -replace '(?m)^\s*isPlayer\s*=\s*1\s*;\r?\n', ''
        $copies = New-Object System.Collections.Generic.List[string]
        for ($k = 0; $k -lt ($PerSide - $playable.Count); $k++) {
            $copy = [regex]::Replace($template, '^class\s+Item\d+', "class Item$($units.Count + $k)")
            $copy = [regex]::Replace($copy, '\bid\s*=\s*\d+\s*;', "id=$nextId;")
            $nextId++
            # a bit beside the template unit (x + 1 m per copy)
            $copy = [regex]::Replace($copy, 'position\[\]\s*=\s*\{([-\d.e]+)', {
                    param($match)
                    $x = [double]::Parse($match.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture) + 1 + $k
                    'position[]={' + $x.ToString([Globalization.CultureInfo]::InvariantCulture)
                })
            $copies.Add($copy)
        }

        $newBody = [regex]::Replace($body, '(?m)^(\s*items\s*=\s*)\d+(\s*;)', { param($match) $match.Groups[1].Value + ($units.Count + $copies.Count) + $match.Groups[2].Value }, 1)
        $newBody = $newBody.TrimEnd() + "`r`n" + ($copies -join "`r`n") + "`r`n"
        $groupText = $groupText.Substring(0, $bodyOpen + 1) + $newBody + $groupText.Substring($bodyClose)
        $text = $text.Substring(0, $group.Start) + $groupText + $text.Substring($group.End)
        $added[$group.Side] = $copies.Count
    }

    [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
    $added
}
