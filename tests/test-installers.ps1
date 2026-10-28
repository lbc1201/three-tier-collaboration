[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$package = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('skill installer test ' + [Guid]::NewGuid().ToString('N'))
$scan = Join-Path $testRoot 'skills'
$target = Join-Path $scan 'three-tier-collaboration'
function Assert([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
}

& (Join-Path $package 'install.ps1') -InstallRoot $scan -WhatIf
Assert (-not (Test-Path -LiteralPath $testRoot)) 'WhatIf mutated the filesystem.'
& (Join-Path $package 'install.ps1') -InstallRoot $scan
Assert (Test-Path -LiteralPath (Join-Path $target 'SKILL.md')) 'Fresh install failed.'
Assert ((Get-FileHash -LiteralPath (Join-Path $target 'SKILL.md')).Hash -eq
    (Get-FileHash -LiteralPath (Join-Path $package 'three-tier-collaboration\SKILL.md')).Hash) 'Installed file differs.'
[IO.File]::WriteAllText((Join-Path $target 'local-note.txt'), 'preserve my changes')
& (Join-Path $package 'install.ps1') -InstallRoot $scan
$old = @(Get-ChildItem -LiteralPath (Join-Path $testRoot 'skill-backups') -Directory -Filter '*before-update*')
Assert ($old.Count -eq 1) 'Update backup missing.'
Assert ([IO.File]::ReadAllText((Join-Path $old[0].FullName 'local-note.txt')) -eq 'preserve my changes') 'Local changes were lost.'
& (Join-Path $package 'uninstall.ps1') -InstallRoot $scan -WhatIf
Assert (Test-Path -LiteralPath $target) 'Uninstall WhatIf mutated target.'
& (Join-Path $package 'uninstall.ps1') -InstallRoot $scan
Assert (-not (Test-Path -LiteralPath $target)) 'Uninstall left target installed.'
$saved = @(Get-ChildItem -LiteralPath (Join-Path $testRoot 'skill-backups') -Directory -Filter '*uninstalled*')
Assert ($saved.Count -eq 1 -and (Test-Path -LiteralPath (Join-Path $saved[0].FullName 'SKILL.md'))) 'Recoverable copy missing.'
& (Join-Path $package 'uninstall.ps1') -InstallRoot $scan

New-Item -ItemType Directory -Path $target -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $target 'SKILL.md'), "---`nname: unrelated-skill`n---`n")
$blocked = $false
try { & (Join-Path $package 'uninstall.ps1') -InstallRoot $scan } catch { $blocked = $true }
Assert $blocked 'Uninstaller accepted an unrelated skill.'
$blocked = $false
try { & (Join-Path $package 'install.ps1') -InstallRoot $scan } catch { $blocked = $true }
Assert $blocked 'Installer overwrote an unrelated skill.'

# Check auto-discovery using process-local environment variables, never real skill folders.
$originalProfile = $env:USERPROFILE
$originalCodexHome = $env:CODEX_HOME
try {
    $env:USERPROFILE = Join-Path $testRoot 'fake-user'
    $env:CODEX_HOME = Join-Path $testRoot 'fake-codex-home'
    . (Join-Path $package 'scripts\skill-paths.ps1')
    Assert ((Get-InstallRoot '') -eq (Get-FullPath (Join-Path $env:CODEX_HOME 'skills'))) 'CODEX_HOME not honored.'
    $env:CODEX_HOME = $null
    Assert ((Get-InstallRoot '') -eq (Get-FullPath (Join-Path $env:USERPROFILE '.agents\skills'))) 'Fresh-user default incorrect.'
    foreach ($relative in @('.codex\skills', '.agents\skills')) {
        New-Item -ItemType Directory -Path (Join-Path $env:USERPROFILE "$relative\three-tier-collaboration") -Force | Out-Null
    }
    $blocked = $false
    try { Get-InstallRoot '' | Out-Null } catch { $blocked = $true }
    Assert $blocked 'Ambiguous multiple installations were not rejected.'
} finally {
    $env:USERPROFILE = $originalProfile
    $env:CODEX_HOME = $originalCodexHome
}
Write-Output "PASS: install, update backup, reversible uninstall, repeat uninstall, WhatIf, identity guard, root selection. Test files: $testRoot"
