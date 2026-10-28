# Byte-preserving edits outside a uniquely marked, package-owned block.
function Get-GlobalAgentsPath([string] $RequestedPath) {
    if ($RequestedPath) { return Get-FullPath $RequestedPath }
    $codexDirectory = Join-Path $env:USERPROFILE '.codex'
    if ($env:CODEX_HOME) { $codexDirectory = $env:CODEX_HOME }
    return Get-FullPath (Join-Path $codexDirectory 'AGENTS.md')
}

function Get-AgentsEdit([string] $Path, [string] $TriggerFile, [bool] $Install) {
    Assert-NoLinks $Path
    if ((Split-Path -Leaf $Path) -ne 'AGENTS.md') { throw 'AgentsPath must name AGENTS.md.' }
    if ($Install) {
        $override = Join-Path (Split-Path -Parent $Path) 'AGENTS.override.md'
        if ((Test-Path -LiteralPath $override -PathType Leaf) -and
            -not [string]::IsNullOrWhiteSpace([IO.File]::ReadAllText($override))) {
            throw "AGENTS.override.md takes precedence. Resolve it before installation: $override"
        }
    }
    $exists = Test-Path -LiteralPath $Path
    [byte[]] $before = @()
    if ($exists) { $before = [IO.File]::ReadAllBytes($Path) }
    $encoding = [Text.UTF8Encoding]::new($false, $true)
    $offset = 0
    if ($before.Length -ge 4 -and (($before[0] -eq 255 -and $before[1] -eq 254 -and $before[2] -eq 0 -and $before[3] -eq 0) -or
        ($before[0] -eq 0 -and $before[1] -eq 0 -and $before[2] -eq 254 -and $before[3] -eq 255))) {
        throw 'UTF-32 AGENTS.md is unsupported; convert to UTF-8 first.'
    } elseif ($before.Length -ge 3 -and $before[0] -eq 239 -and $before[1] -eq 187 -and $before[2] -eq 191) {
        $offset = 3
    } elseif ($before.Length -ge 2 -and $before[0] -eq 255 -and $before[1] -eq 254) {
        $encoding = [Text.UnicodeEncoding]::new($false, $false, $true); $offset = 2
    } elseif ($before.Length -ge 2 -and $before[0] -eq 254 -and $before[1] -eq 255) {
        $encoding = [Text.UnicodeEncoding]::new($true, $false, $true); $offset = 2
    }
    $text = $encoding.GetString($before, $offset, $before.Length - $offset)
    if ($text.Contains([char]0)) { throw 'Unsupported AGENTS.md encoding (contains NUL characters).' }
    $begin = '<!-- BEGIN three-tier-collaboration managed trigger -->'
    $end = '<!-- END three-tier-collaboration managed trigger -->'
    $starts = [regex]::Matches($text, [regex]::Escape($begin))
    $ends = [regex]::Matches($text, [regex]::Escape($end))
    if ($starts.Count -gt 1 -or $ends.Count -gt 1 -or $starts.Count -ne $ends.Count) {
        throw 'Malformed or duplicate managed markers. No changes made.'
    }
    if ($starts.Count -eq 1 -and $ends[0].Index -lt $starts[0].Index) { throw 'Managed markers are out of order.' }
    $newline = "`n"
    if ($text.Contains("`r`n")) { $newline = "`r`n" }
    $block = ''
    if ($Install) {
        $block = [IO.File]::ReadAllText($TriggerFile).TrimEnd([char[]]"`r`n") -replace '\r?\n', $newline
        if (-not $block.StartsWith($begin) -or -not $block.EndsWith($end)) { throw 'Invalid packaged trigger block.' }
    }
    if ($starts.Count -eq 1) {
        $length = $ends[0].Index + $end.Length - $starts[0].Index
        $afterText = $text.Substring(0, $starts[0].Index) + $block + $text.Substring($starts[0].Index + $length)
    } elseif ($Install) {
        $separator = ''
        if ($text.Length -gt 0) { $separator = $newline + $newline }
        $afterText = $text + $separator + $block + $newline
    } else { $afterText = $text }
    [byte[]] $preamble = @()
    if ($offset -gt 0) { $preamble = $before[0..($offset - 1)] }
    [byte[]] $after = $preamble + $encoding.GetBytes($afterText)
    return [pscustomobject]@{ Path = $Path; Existed = $exists; Before = $before; After = $after;
        Changed = ([Convert]::ToBase64String($before) -ne [Convert]::ToBase64String($after)) }
}

function Save-AgentsEdit($Edit, [string] $BackupRoot) {
    if (-not $Edit.Changed) { return }
    Assert-NoLinks $Edit.Path
    $existsNow = Test-Path -LiteralPath $Edit.Path
    if ($existsNow -ne $Edit.Existed) { throw 'AGENTS.md changed during installation; retry after reviewing it.' }
    if ($existsNow -and [Convert]::ToBase64String([IO.File]::ReadAllBytes($Edit.Path)) -ne
        [Convert]::ToBase64String($Edit.Before)) { throw 'AGENTS.md changed during installation; retry after reviewing it.' }
    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
    if ($Edit.Existed) {
        $backup = (New-BackupPath $BackupRoot 'AGENTS-before-edit') + '.md'
        [IO.File]::WriteAllBytes($backup, $Edit.Before)
        Write-Output "AGENTS.md backup: $backup"
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $Edit.Path) -Force | Out-Null
    $temporary = $Edit.Path + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    [IO.File]::WriteAllBytes($temporary, $Edit.After)
    Move-Item -LiteralPath $temporary -Destination $Edit.Path -Force
    Write-Output "Managed trigger updated: $($Edit.Path)"
}
