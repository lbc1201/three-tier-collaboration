# Requires Windows PowerShell 5.1 or PowerShell 7. No administrator privileges required.
[CmdletBinding(SupportsShouldProcess = $true)]
param([string] $InstallRoot, [string] $AgentsPath)

. (Join-Path $PSScriptRoot 'scripts\skill-paths.ps1')
. (Join-Path $PSScriptRoot 'scripts\agents-trigger.ps1')

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
if ((Test-Inside $agentsFile $target) -or (Test-Inside $agentsFile $source)) {
    throw 'Global AGENTS.md must be outside the package and installation directories.'
}
if (-not $PSCmdlet.ShouldProcess("$target ; $agentsFile", 'Install v1.1 skill and upsert managed global trigger; back up existing files')) { return }

New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$staging = New-BackupPath $backupRoot 'staging'
$previous = $null
$newInstalled = $false
try {
    Copy-Item -LiteralPath $source -Destination $staging -Recurse
    Assert-Skill $staging
    foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File -Force) {
        $relative = $file.FullName.Substring($source.Length + 1)
        if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne
            (Get-FileHash -LiteralPath (Join-Path $staging $relative) -Algorithm SHA256).Hash) {
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
    Write-Output "Installed: $target"
    if ($previous) { Write-Output "Previous version: $previous" }
    Write-Output 'v1.1 installed. Start a new chat to load global guidance; restart Codex if needed.'
} catch {
    $failure = $_
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
