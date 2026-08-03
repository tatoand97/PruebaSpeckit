[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ProjectPath,

    [Parameter()]
    [ValidateSet('codex', 'github-copilot')]
    [string[]]$Tools = @('codex', 'github-copilot'),

    [Parameter()]
    [switch]$BackupExisting
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = $PSScriptRoot
$targetRoot = [IO.Path]::GetFullPath($ProjectPath)
if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) {
    throw "Target project does not exist: $targetRoot"
}

$nodeCommand = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCommand) { throw 'Node.js is required.' }
$nodeText = (& $nodeCommand.Source --version).Trim().TrimStart('v')
$nodeVersion = [version]$nodeText
if ($nodeVersion -lt [version]'20.19.0') {
    throw "Node.js 20.19.0 or newer is required; found $nodeText."
}

$openSpecCommand = Get-Command openspec -ErrorAction SilentlyContinue
if (-not $openSpecCommand) {
    throw 'OpenSpec CLI is required. Install @fission-ai/openspec before running this installer.'
}
$openSpecVersion = (& $openSpecCommand.Source --version).Trim()

foreach ($legacyPath in @(('.' + 'specify'), ('.github/skills/' + 'spec' + 'kit-specify'))) {
    if (Test-Path -LiteralPath (Join-Path $targetRoot $legacyPath)) {
        throw "An active legacy SDD path exists at '$legacyPath'. Preserve and migrate it before installing OpenSpec."
    }
}

$payload = [System.Collections.Generic.List[object]]::new()
function Add-Payload([string]$Source, [string]$Destination) {
    $payload.Add([pscustomobject]@{
        Source = [IO.Path]::GetFullPath($Source)
        Destination = [IO.Path]::GetFullPath($Destination)
    })
}

foreach ($file in Get-ChildItem -LiteralPath (Join-Path $packageRoot 'schema') -Recurse -File) {
    $relative = $file.FullName.Substring((Join-Path $packageRoot 'schema').Length).TrimStart('\', '/')
    Add-Payload $file.FullName (Join-Path $targetRoot "openspec/schemas/dotnet-sdd/$relative")
}
Add-Payload (Join-Path $packageRoot 'tools/dotnet-sdd-guard/Invoke-DotNetSddGuard.ps1') (Join-Path $targetRoot 'tools/dotnet-sdd-guard/Invoke-DotNetSddGuard.ps1')
Add-Payload (Join-Path $packageRoot 'scripts/Invoke-OpenSpecSddGuard.ps1') (Join-Path $targetRoot 'scripts/Invoke-OpenSpecSddGuard.ps1')

if ('codex' -in $Tools) {
    Add-Payload (Join-Path $packageRoot 'skills/codex/dotnet-sdd-verify/SKILL.md') (Join-Path $targetRoot '.codex/skills/dotnet-sdd-verify/SKILL.md')
    Add-Payload (Join-Path $packageRoot 'skills/codex/dotnet-sdd-verify/agents/openai.yaml') (Join-Path $targetRoot '.codex/skills/dotnet-sdd-verify/agents/openai.yaml')
}
if ('github-copilot' -in $Tools) {
    Add-Payload (Join-Path $packageRoot 'skills/github-copilot/dotnet-sdd-verify/SKILL.md') (Join-Path $targetRoot '.github/skills/dotnet-sdd-verify/SKILL.md')
}

$collisions = @($payload | Where-Object {
    (Test-Path -LiteralPath $_.Destination -PathType Leaf) -and
    (Get-FileHash -LiteralPath $_.Source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $_.Destination -Algorithm SHA256).Hash
})
if ($collisions.Count -gt 0 -and -not $BackupExisting) {
    $paths = $collisions | ForEach-Object { $_.Destination.Substring($targetRoot.Length + 1) }
    throw "Installation would overwrite $($collisions.Count) differing file(s): $($paths -join ', '). Re-run with -BackupExisting after review."
}

$toolArgument = $Tools -join ','
$hasOpenSpecRoot = Test-Path -LiteralPath (Join-Path $targetRoot 'openspec') -PathType Container
Push-Location -LiteralPath $targetRoot
try {
    if ($hasOpenSpecRoot) {
        & $openSpecCommand.Source update --force
    } else {
        & $openSpecCommand.Source init . --tools $toolArgument --force --no-animation
    }
    if ($LASTEXITCODE -ne 0) { throw 'OpenSpec tool integration generation failed.' }
}
finally {
    Pop-Location
}

$backupStamp = Get-Date -Format 'yyyyMMddHHmmss'
foreach ($item in $payload) {
    $destinationDirectory = Split-Path -Parent $item.Destination
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    if (Test-Path -LiteralPath $item.Destination -PathType Leaf) {
        $same = (Get-FileHash -LiteralPath $item.Source -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $item.Destination -Algorithm SHA256).Hash
        if ($same) { continue }
        Copy-Item -LiteralPath $item.Destination -Destination "$($item.Destination).backup-$backupStamp"
    }
    Copy-Item -LiteralPath $item.Source -Destination $item.Destination -Force
}

$configPath = Join-Path $targetRoot 'openspec/config.yaml'
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    $config = Get-Content -LiteralPath $configPath -Raw
    if ($config -match '(?m)^schema:\s*spec-driven\s*$') {
        $config = $config -replace '(?m)^schema:\s*spec-driven\s*$', 'schema: dotnet-sdd'
        Set-Content -LiteralPath $configPath -Value $config -Encoding utf8NoBOM -NoNewline
    } elseif ($config -notmatch '(?m)^schema:\s*dotnet-sdd\s*$') {
        Write-Warning 'Existing config.yaml uses another schema; it was preserved. Select dotnet-sdd explicitly or update the configuration after review.'
    }
}

Push-Location -LiteralPath $targetRoot
try {
    & $openSpecCommand.Source schema validate dotnet-sdd --verbose
    if ($LASTEXITCODE -ne 0) { throw 'Installed dotnet-sdd schema is invalid.' }
}
finally {
    Pop-Location
}

Write-Output "Installed dotnet-sdd 2.0.0 into $targetRoot"
Write-Output "Node.js: $nodeText; OpenSpec: $openSpecVersion; tools: $toolArgument"
Write-Output 'Next: openspec validate --all --strict'
Write-Output 'Next change: use $openspec-propose in Codex or /opsx-propose in GitHub Copilot.'
