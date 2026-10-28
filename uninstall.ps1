# Uninstall by moving the skill outside discovery directories; no recursive deletion.
[CmdletBinding(SupportsShouldProcess = $true)]
param([string] $InstallRoot, [string] $AgentsPath, [string] $ConfigPath)

. (Join-Path $PSScriptRoot 'scripts\skill-paths.ps1')
. (Join-Path $PSScriptRoot 'scripts\agents-trigger.ps1')
. (Join-Path $PSScriptRoot 'scripts\config-merge.ps1')

$root = Get-InstallRoot $InstallRoot
$target = Get-FullPath (Join-Path $root $script:SkillName)
Assert-NoLinks $root
if (-not (Test-Inside $target $root)) { throw 'Target is outside the selected skill directory.' }
$hasSkill = Test-Path -LiteralPath $target
if ($hasSkill) { Assert-Skill $target }
$agentsFile = Get-GlobalAgentsPath $AgentsPath
if (Test-Inside $agentsFile $target) { throw 'Global AGENTS.md must be outside the installation directory.' }
$agentsEdit = Get-AgentsEdit $agentsFile '' $false
if (-not $ConfigPath) { $ConfigPath = Join-Path (Split-Path -Parent $agentsFile) 'config.toml' }
$ConfigPath = Get-FullPath $ConfigPath
if (Test-Inside $ConfigPath $target) { throw 'ConfigPath must be outside the skill installation.' }
$configPlan = Get-ConfigPlan 'uninstall' $ConfigPath
if (-not $hasSkill -and -not $agentsEdit.Changed -and $null -eq $configPlan) { Write-Output "Already uninstalled: $target"; return }
$backupRoot = Get-BackupRoot $root
$saved = New-BackupPath $backupRoot 'uninstalled'
if (-not $PSCmdlet.ShouldProcess("$target ; $agentsFile ; $ConfigPath", "Move skill to $saved; remove managed trigger and restore owned config values")) { return }
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
if ($hasSkill) {
    Assert-Skill $target
    Move-Item -LiteralPath $target -Destination $saved
}
$agentsSaved = $false
try {
    Save-AgentsEdit $agentsEdit $backupRoot
    $agentsSaved = $true
    Save-ConfigPlan $configPlan $backupRoot
} catch {
    if ($agentsSaved) { Restore-AgentsEdit $agentsEdit }
    if ($hasSkill -and (Test-Path -LiteralPath $saved) -and -not (Test-Path -LiteralPath $target)) {
        Assert-NoLinks $target
        Move-Item -LiteralPath $saved -Destination $target
    }
    throw
}
if (Test-Path -LiteralPath $target) { throw "Uninstall incomplete: $target" }
if ($hasSkill) { Write-Output "Uninstalled. Recoverable copy: $saved" }
Write-Output 'Managed trigger removed; other global instructions preserved.'
Write-Output 'Restart Codex if the old skill entry remains visible.'
