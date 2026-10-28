function Get-ConfigPlan([string] $Action, [string] $ConfigPath) {
    $path = Get-FullPath $ConfigPath
    Assert-NoLinks $path
    Assert-NoLinks ($path + '.three-tier-collaboration.json')
    if ($Action -eq 'uninstall' -and -not (Test-Path -LiteralPath ($path + '.three-tier-collaboration.json'))) {
        return $null
    }
    $candidates = @('python', 'python3')
    $runtime = $null
    foreach ($candidate in $candidates) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($command) {
            & $command.Source -c 'import sys,tomllib; sys.exit(0 if sys.version_info >= (3,11) else 1)' 2>$null
            if ($LASTEXITCODE -eq 0) { $runtime = $command.Source; break }
        }
    }
    if (-not $runtime) { throw 'Python 3.11+ is required for safe TOML merging. Install Python, then retry; no changes made.' }
    $helper = Join-Path (Split-Path -Parent $PSScriptRoot) 'three-tier-collaboration\scripts\config-merge.py'
    $json = (& $runtime $helper ('plan-' + $Action) --config $path | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Config preflight failed; no installation changes made.' }
    $null = $json | ConvertFrom-Json
    return [pscustomobject]@{ Runtime = $runtime; Helper = $helper; Json = $json }
}

function Save-ConfigPlan($Plan, [string] $BackupRoot, [switch] $Rollback) {
    if ($null -eq $Plan) { return }
    $action = 'apply'
    if ($Rollback) { $action = 'rollback' }
    $Plan.Json | & $Plan.Runtime $Plan.Helper $action --backup-root $BackupRoot
    if ($LASTEXITCODE -ne 0) { throw "Config $action failed; review preserved backups." }
}

function Restore-AgentsEdit($Edit) {
    if (-not $Edit.Changed) { return }
    Assert-NoLinks $Edit.Path
    if ((Test-Path -LiteralPath $Edit.Path) -and
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($Edit.Path)) -eq [Convert]::ToBase64String($Edit.After)) {
        [IO.File]::WriteAllBytes($Edit.Path, $Edit.Before)
    } else { Write-Warning 'AGENTS.md changed after the edit; preserved it for manual review.' }
}
