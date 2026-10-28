[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$package = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('skill installer test ' + [Guid]::NewGuid().ToString('N'))
$scan = Join-Path $testRoot 'skills'
$target = Join-Path $scan 'three-tier-collaboration'
$agents = Join-Path $testRoot 'global\AGENTS.md'
function Assert([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
}

& (Join-Path $package 'install.ps1') -InstallRoot $scan -AgentsPath $agents -WhatIf
Assert (-not (Test-Path -LiteralPath $testRoot)) 'WhatIf mutated the filesystem.'
New-Item -ItemType Directory -Path (Split-Path -Parent $agents) -Force | Out-Null
$config = Join-Path (Split-Path -Parent $agents) 'config.toml'
[IO.File]::WriteAllText($config, "# retain config comment`nmodel = 'before-install'`napproval_policy = 'on-request'`n")
& (Join-Path $package 'install.ps1') -InstallRoot $scan -AgentsPath $agents
Assert (Test-Path -LiteralPath (Join-Path $target 'SKILL.md')) 'Fresh install failed.'
Assert ((Get-FileHash -LiteralPath (Join-Path $target 'SKILL.md')).Hash -eq
    (Get-FileHash -LiteralPath (Join-Path $package 'three-tier-collaboration\SKILL.md')).Hash) 'Installed file differs.'
[IO.File]::WriteAllText((Join-Path $target 'local-note.txt'), 'preserve my changes')
$existingRules = "# User rules`r`nKeep my preferences.`r`n"
[IO.File]::WriteAllText($agents, $existingRules, [Text.UTF8Encoding]::new($true))
& (Join-Path $package 'install.ps1') -InstallRoot $scan -AgentsPath $agents
$installedRules = [IO.File]::ReadAllText($agents)
Assert ($installedRules.StartsWith($existingRules)) 'Existing global rules changed.'
Assert ([regex]::Matches($installedRules, '<!-- BEGIN three-tier-collaboration managed trigger -->').Count -eq 1) 'Trigger missing or duplicated.'
$globalBackups = @(Get-ChildItem -LiteralPath (Join-Path $testRoot 'skill-backups') -File -Filter '*AGENTS-before-edit*')
Assert ($globalBackups.Count -eq 1) 'AGENTS.md backup missing.'
Assert ([IO.File]::ReadAllText($globalBackups[0].FullName) -eq $existingRules) 'AGENTS.md backup differs.'
& (Join-Path $package 'install.ps1') -InstallRoot $scan -AgentsPath $agents
Assert ([IO.File]::ReadAllText($agents) -eq $installedRules) 'Repeated install changed trigger.'
$old = @(Get-ChildItem -LiteralPath (Join-Path $testRoot 'skill-backups') -Directory -Filter '*before-update*')
Assert ($old.Count -eq 2) 'Update backup missing.'
$withNote = @($old | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'local-note.txt') })
Assert ($withNote.Count -eq 1) 'Modified version backup missing.'
Assert ([IO.File]::ReadAllText((Join-Path $withNote[0].FullName 'local-note.txt')) -eq 'preserve my changes') 'Local changes were lost.'
& (Join-Path $package 'uninstall.ps1') -InstallRoot $scan -AgentsPath $agents -WhatIf
Assert (Test-Path -LiteralPath $target) 'Uninstall WhatIf mutated target.'
Assert ([IO.File]::ReadAllText($agents) -eq $installedRules) 'Uninstall WhatIf changed global rules.'
[IO.File]::AppendAllText($agents, "`r`n# Later user edit`r`nRetain this too.")
& (Join-Path $package 'uninstall.ps1') -InstallRoot $scan -AgentsPath $agents
Assert ([IO.File]::ReadAllText($agents).StartsWith($existingRules)) 'Uninstall changed existing rules.'
Assert ([IO.File]::ReadAllText($agents).Contains('Retain this too.')) 'Uninstall lost later user edits.'
Assert (-not [IO.File]::ReadAllText($agents).Contains('<!-- BEGIN three-tier-collaboration managed trigger -->')) 'Trigger still present.'
Assert ([IO.File]::ReadAllText($config).Contains('before-install')) 'Original model was not restored.'
Assert ([IO.File]::ReadAllText($config).Contains("approval_policy = 'on-request'")) 'Unrelated config changed.'
Assert (-not (Test-Path -LiteralPath $target)) 'Uninstall left target installed.'
$saved = @(Get-ChildItem -LiteralPath (Join-Path $testRoot 'skill-backups') -Directory -Filter '*uninstalled*')
Assert ($saved.Count -eq 1 -and (Test-Path -LiteralPath (Join-Path $saved[0].FullName 'SKILL.md'))) 'Recoverable copy missing.'
& (Join-Path $package 'uninstall.ps1') -InstallRoot $scan -AgentsPath $agents

New-Item -ItemType Directory -Path $target -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $target 'SKILL.md'), "---`nname: unrelated-skill`n---`n")
$blocked = $false
try { & (Join-Path $package 'uninstall.ps1') -InstallRoot $scan -AgentsPath $agents } catch { $blocked = $true }
Assert $blocked 'Uninstaller accepted an unrelated skill.'
$blocked = $false
try { & (Join-Path $package 'install.ps1') -InstallRoot $scan -AgentsPath $agents } catch { $blocked = $true }
Assert $blocked 'Installer overwrote an unrelated skill.'

. (Join-Path $package 'scripts\skill-paths.ps1')
. (Join-Path $package 'scripts\agents-trigger.ps1')
$trigger = Join-Path $package 'assets\agents-trigger.md'
$encodingCases = @([Text.UTF8Encoding]::new($false), [Text.UTF8Encoding]::new($true),
    [Text.UnicodeEncoding]::new($false, $true), [Text.UnicodeEncoding]::new($true, $true))
foreach ($codec in $encodingCases) {
    $sample = "# Existing rules`r`nPreserve this exactly.`r`n"
    [IO.File]::WriteAllText($agents, $sample, $codec)
    $originalBytes = [IO.File]::ReadAllBytes($agents)
    $edit = Get-AgentsEdit $agents $trigger $true
    Save-AgentsEdit $edit (Join-Path $testRoot 'skill-backups') | Out-Null
    $updatedBytes = [IO.File]::ReadAllBytes($agents)
    Assert ([Convert]::ToBase64String($updatedBytes[0..($originalBytes.Length - 1)]) -eq
        [Convert]::ToBase64String($originalBytes)) 'Existing bytes or BOM changed.'
    $edit = Get-AgentsEdit $agents '' $false
    Save-AgentsEdit $edit (Join-Path $testRoot 'skill-backups') | Out-Null
    Assert ([IO.File]::ReadAllText($agents).StartsWith($sample)) 'Encoding roundtrip failed.'
}
[IO.File]::WriteAllText($agents, '<!-- BEGIN three-tier-collaboration managed trigger -->')
$blocked = $false
try { Get-AgentsEdit $agents $trigger $true | Out-Null } catch { $blocked = $true }
Assert $blocked 'Malformed markers were accepted.'
[IO.File]::WriteAllText($agents, '# Existing rules')
$edit = Get-AgentsEdit $agents $trigger $true
[IO.File]::AppendAllText($agents, ' concurrent edit')
$blocked = $false
try { Save-AgentsEdit $edit (Join-Path $testRoot 'skill-backups') | Out-Null } catch { $blocked = $true }
Assert $blocked 'Concurrent edit was overwritten.'
Assert ([IO.File]::ReadAllText($agents).Contains('concurrent edit')) 'Concurrent edit lost.'
$override = Join-Path (Split-Path -Parent $agents) 'AGENTS.override.md'
[IO.File]::WriteAllText($override, '# Takes precedence')
$blocked = $false
try { Get-AgentsEdit $agents $trigger $true | Out-Null } catch { $blocked = $true }
Assert $blocked 'Nonempty global override was ignored.'
[IO.File]::WriteAllText($override, '')
[IO.File]::WriteAllText($agents, $installedRules)
& (Join-Path $package 'uninstall.ps1') -InstallRoot (Join-Path $testRoot 'orphan-skills') -AgentsPath $agents
Assert (-not [IO.File]::ReadAllText($agents).Contains('<!-- BEGIN three-tier-collaboration managed trigger -->')) 'Orphan trigger was not removed.'

# Check auto-discovery using process-local environment variables, never real skill folders.
$originalProfile = $env:USERPROFILE
$originalCodexHome = $env:CODEX_HOME
try {
    $env:USERPROFILE = Join-Path $testRoot 'fake-user'
    $env:CODEX_HOME = Join-Path $testRoot 'fake-codex-home'
    . (Join-Path $package 'scripts\skill-paths.ps1')
    Assert ((Get-GlobalAgentsPath '') -eq (Get-FullPath (Join-Path $env:CODEX_HOME 'AGENTS.md'))) 'Global CODEX_HOME not honored.'
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
$testedVersion = [IO.File]::ReadAllText((Join-Path $package 'VERSION')).Trim()
Write-Output "PASS v${testedVersion}: install/update/uninstall, config merge/restore, backups, idempotent trigger, preserved user edits, encodings, marker and concurrency guards, override guard, orphan cleanup, WhatIf and root selection. Test files: $testRoot"
