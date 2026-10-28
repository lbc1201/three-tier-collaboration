# Uninstall by moving the skill outside discovery directories; no recursive deletion.
[CmdletBinding(SupportsShouldProcess = $true)]
param([string] $InstallRoot)

. (Join-Path $PSScriptRoot 'scripts\skill-paths.ps1')

$root = Get-InstallRoot $InstallRoot
$target = Get-FullPath (Join-Path $root $script:SkillName)
Assert-NoLinks $root
if (-not (Test-Inside $target $root)) { throw 'Target is outside the selected skill directory.' }
if (-not (Test-Path -LiteralPath $target)) {
    Write-Output "Already uninstalled: $target"
    return
}
Assert-Skill $target
$backupRoot = Get-BackupRoot $root
$saved = New-BackupPath $backupRoot 'uninstalled'
if (-not $PSCmdlet.ShouldProcess($target, "Uninstall by moving to $saved")) { return }
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
Assert-Skill $target
Move-Item -LiteralPath $target -Destination $saved
if (Test-Path -LiteralPath $target) { throw "Uninstall incomplete: $target" }
Write-Output "Uninstalled. Recoverable copy: $saved"
Write-Output 'Restart Codex if the old skill entry remains visible.'
