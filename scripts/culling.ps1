# Build-time HC slot insertion. Never modifies the authoritative editor/source mission.sqm.
function Add-CullingSlot([string]$MissionPath, [string]$CfgConvert) {
    $path = Join-Path $MissionPath 'mission.sqm'
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes.Length -gt 4 -and $bytes[0] -eq 0 -and $bytes[1] -eq 114) {
        $decoded = Join-Path $MissionPath 'mission.culling.txt'
        & $CfgConvert -txt -dst $decoded $path | Out-Null
        if ($LASTEXITCODE -ne 0 -or !(Test-Path $decoded)) {
            throw 'Cannot decode staged mission.sqm for culling HC'
        }
        $text = [IO.File]::ReadAllText($decoded)
        Remove-Item -LiteralPath $decoded
    } else {
        $text = [IO.File]::ReadAllText($path)
    }
    if ($text -match 'type\s*=\s*"HeadlessClient_F"') {
        return
    }
    $mission = [regex]::Match($text, '\bclass\s+Mission\s*\{')
    if (!$mission.Success) {
        throw 'Mission class missing in staged SQM'
    }
    $entities = [regex]::Match($text.Substring($mission.Index + $mission.Length), '\bclass\s+Entities\s*\{')
    if (!$entities.Success) {
        throw 'Eden Mission/Entities missing in staged SQM'
    }
    $start = $mission.Index + $mission.Length + $entities.Index + $entities.Length
    $depth = 1
    $quoted = $false
    $end = $start
    for (; $end -lt $text.Length; $end++) {
        $c = $text[$end]
        if ($c -eq '"') {
            if ($quoted -and $end + 1 -lt $text.Length -and $text[$end + 1] -eq '"') {
                $end++
                continue
            }
            $quoted = !$quoted
        }
        if ($quoted) {
            continue
        }
        if ($c -eq '{') {
            $depth++
        }
        if ($c -eq '}') {
            $depth--
            if ($depth -eq 0) {
                break
            }
        }
    }
    if ($depth -ne 0) {
        throw 'Unbalanced staged Mission/Entities'
    }
    $body = $text.Substring($start, $end - $start)
    $items = [regex]::Match($body, '^\s*items\s*=\s*(\d+)\s*;', 'Multiline')
    if (!$items.Success) {
        throw 'Mission/Entities item count missing'
    }
    $count = [int]$items.Groups[1].Value
    $id = 1 + ([regex]::Matches($text, '\bid\s*=\s*(\d+)\s*;') | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Maximum).Maximum
    $slot = @"

class Item$count {
    dataType="Logic";
    class PositionInfo { position[]={0,0,0}; };
    name="CU_workerSlot";
    isPlayable=1;
    description="Entity culling worker";
    id=$id;
    type="HeadlessClient_F";
};
"@
    $body = $body.Remove($items.Index, $items.Length).Insert($items.Index, "`r`nitems=$($count + 1);")
    $text = $text.Substring(0, $start) + $body + $slot + $text.Substring($end)
    [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
    $description = Join-Path $MissionPath 'Description.ext'
    $config = [IO.File]::ReadAllText($description)
    $config = [regex]::Replace($config, '(?m)(^\s*maxPlayers\s*=\s*)(\d+)(\s*;)', {
            param($match) $match.Groups[1].Value + ([int]$match.Groups[2].Value + 1) + $match.Groups[3].Value
        })
    [IO.File]::WriteAllText($description, $config, (New-Object Text.UTF8Encoding($false)))
}
