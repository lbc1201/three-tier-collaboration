# Requires Windows PowerShell 5.1 or PowerShell 7. No administrator privileges required.
[CmdletBinding(SupportsShouldProcess = $true)]
param([string] $InstallRoot, [string] $AgentsPath, [string] $ConfigPath)

. (Join-Path $PSScriptRoot 'scripts\skill-paths.ps1')
. (Join-Path $PSScriptRoot 'scripts\agents-trigger.ps1')
. (Join-Path $PSScriptRoot 'scripts\config-merge.ps1')

$source = Get-FullPath (Join-Path $PSScriptRoot $script:SkillName)
Assert-Skill $source
$root = Get-InstallRoot $InstallRoot
$target = Get-FullPath (Join-Path $root $script:SkillName)
Assert-NoLinks $root
if (-not (Test-Inside $target $root) -or (Test-Inside $target $source) -or
    (Test-Inside $source $target)) { throw 'Source and destination must be separate directories.' }
if (Test-Path -LiteralPath $target) { Assert-Skill $target }
$backupRoot = Get-BackupRoot $root
if ((Test-Inside $backupRoot $source) -or (Test-Inside $source $backupRoot)) {
    throw 'Backup and package source must be separate directories.'
}
$agentsFile = Get-GlobalAgentsPath $AgentsPath
$agentsEdit = Get-AgentsEdit $agentsFile (Join-Path $PSScriptRoot 'assets\agents-trigger.md') $true
if (-not $ConfigPath) { $ConfigPath = Join-Path (Split-Path -Parent $agentsFile) 'config.toml' }
$ConfigPath = Get-FullPath $ConfigPath
if ((Test-Inside $ConfigPath $target) -or (Test-Inside $ConfigPath $source)) { throw 'ConfigPath must be outside the skill source and target.' }
$configPlan = Get-ConfigPlan 'install' $ConfigPath
if ((Test-Inside $agentsFile $target) -or (Test-Inside $agentsFile $source)) {
    throw 'Global AGENTS.md must be outside the package and installation directories.'
}
if (-not $PSCmdlet.ShouldProcess("$target ; $agentsFile ; $ConfigPath", 'Install v1.2 skill, global trigger and six configuration defaults; back up existing files')) { return }

New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$staging = New-BackupPath $backupRoot 'staging'
$previous = $null
$newInstalled = $false
$agentsSaved = $false
$configSaved = $false
try {
    Copy-Item -LiteralPath $source -Destination $staging -Recurse
    Assert-Skill $staging
    foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File -Force) {
        $relative = $file.FullName.Substring($source.Length + 1)
        if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($file.FullName)) -ne
            [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $staging $relative)))) {
            throw "Copy verification failed: $relative"
        }
    }
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    if (Test-Path -LiteralPath $target) {
        Assert-Skill $target
        $previous = New-BackupPath $backupRoot 'before-update'
        Move-Item -LiteralPath $target -Destination $previous
    }
    Move-Item -LiteralPath $staging -Destination $target
    $newInstalled = $true
    Assert-Skill $target
    Save-AgentsEdit $agentsEdit $backupRoot
    $agentsSaved = $true
    Save-ConfigPlan $configPlan $backupRoot
    $configSaved = $true
    Write-Output "Installed: $target"
    if ($previous) { Write-Output "Previous version: $previous" }
    Write-Output 'v1.2 installed. Restart Codex to reload configuration and global guidance.'
} catch {
    $failure = $_
    if ($configSaved) { Save-ConfigPlan $configPlan $backupRoot -Rollback }
    if ($agentsSaved) { Restore-AgentsEdit $agentsEdit }
    if ($newInstalled -and (Test-Path -LiteralPath $target)) {
        Assert-Skill $target
        $failedCopy = New-BackupPath $backupRoot 'failed-install'
        Move-Item -LiteralPath $target -Destination $failedCopy
        Write-Warning "Failed installation preserved at: $failedCopy"
    }
    if ($previous -and (Test-Path -LiteralPath $previous) -and -not (Test-Path -LiteralPath $target)) {
        Assert-NoLinks $target
        Move-Item -LiteralPath $previous -Destination $target
        Write-Warning 'Previous version restored.'
    }
    Write-Warning "Staging files, if present, are preserved at: $staging"
    throw $failure
}
