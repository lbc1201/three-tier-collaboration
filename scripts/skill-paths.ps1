Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:SkillName = 'three-tier-collaboration'

function Get-FullPath([string] $Path) {
    if (-not [IO.Path]::IsPathRooted($Path)) {
        $Path = Join-Path (Get-Location).ProviderPath $Path
    }
    $full = [IO.Path]::GetFullPath($Path)
    if ($full -eq [IO.Path]::GetPathRoot($full)) { return $full }
    return $full.TrimEnd([char[]]'\/')
}

function Test-Inside([string] $Child, [string] $Parent) {
    return $Child.Equals($Parent, [StringComparison]::OrdinalIgnoreCase) -or
        $Child.StartsWith($Parent.TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-NoLinks([string] $Path) {
    $current = Get-FullPath $Path
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing symbolic link or junction: $current"
            }
        }
        $parent = Split-Path -Parent $current
        if ($parent -eq $current) { break }
        $current = $parent
    }
}

function Get-KnownRoots {
    $roots = @()
    if ($env:CODEX_HOME) { $roots += Join-Path $env:CODEX_HOME 'skills' }
    $roots += Join-Path $env:USERPROFILE '.codex\skills'
    $roots += Join-Path $env:USERPROFILE '.agents\skills'
    return @($roots | ForEach-Object { Get-FullPath $_ } | Select-Object -Unique)
}

function Get-InstallRoot([string] $RequestedRoot) {
    if ($RequestedRoot) { return Get-FullPath $RequestedRoot }
    $roots = @(Get-KnownRoots)
    $installed = @($roots | Where-Object { Test-Path -LiteralPath (Join-Path $_ $script:SkillName) })
    if ($installed.Count -gt 1) { throw 'Multiple installations found. Specify -InstallRoot explicitly.' }
    if ($installed.Count -eq 1) { return $installed[0] }
    if ($env:CODEX_HOME) { return Get-FullPath (Join-Path $env:CODEX_HOME 'skills') }
    $existing = @($roots | Where-Object { Test-Path -LiteralPath $_ -PathType Container })
    if ($existing.Count -gt 0) { return $existing[0] }
    return Get-FullPath (Join-Path $env:USERPROFILE '.agents\skills')
}

function Assert-Skill([string] $Folder) {
    Assert-NoLinks $Folder
    $manifest = Join-Path $Folder 'SKILL.md'
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { throw "Missing SKILL.md: $Folder" }
    $text = [IO.File]::ReadAllText($manifest)
    if ($text -notmatch '(?s)\A---\r?\n.*?\r?\n---(?:\r?\n|$)' -or
        $Matches[0] -notmatch '(?m)^name:\s*three-tier-collaboration\s*$') {
        throw "Unexpected skill identity: $manifest"
    }
    $links = @(Get-ChildItem -LiteralPath $Folder -Recurse -Force | Where-Object {
        $_.Attributes -band [IO.FileAttributes]::ReparsePoint
    })
    if ($links.Count -gt 0) { throw "Skill contains links or junctions: $Folder" }
}

function Get-BackupRoot([string] $Root) {
    $backup = Get-FullPath (Join-Path (Split-Path -Parent $Root) 'skill-backups')
    foreach ($scanRoot in @((Get-KnownRoots)) + @($Root)) {
        if (Test-Inside $backup $scanRoot) { throw "Backup would be inside a skill scan directory: $backup" }
    }
    Assert-NoLinks $backup
    return $backup
}

function New-BackupPath([string] $BackupRoot, [string] $Label) {
    return Join-Path $BackupRoot ($script:SkillName + '-' + $Label + '-' +
        (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
}
