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

$RequiredOpenSpecVersion = [version]'1.7.0'
$SupportedOpenSpecMajor = 1
$packageRoot = $PSScriptRoot
$targetRoot = [IO.Path]::GetFullPath($ProjectPath)
if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) {
    throw "Target project does not exist: $targetRoot"
}

$nodeCommand = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCommand) { throw 'Node.js is required.' }
$nodeText = (& $nodeCommand.Source --version).Trim().TrimStart('v')
try {
    $nodeVersion = [version]$nodeText
} catch {
    throw "Could not parse the installed Node.js version: '$nodeText'."
}
if ($nodeVersion -lt [version]'20.19.0') {
    throw "Node.js 20.19.0 or newer is required; found $nodeText."
}

$openSpecCommand = Get-Command openspec -ErrorAction SilentlyContinue
if (-not $openSpecCommand) {
    throw 'OpenSpec CLI is required. Install @fission-ai/openspec before running this installer.'
}
$openSpecVersionText = (& $openSpecCommand.Source --version 2>&1 | Out-String).Trim()
$openSpecVersionMatch = [regex]::Match($openSpecVersionText, '(?<!\d)(\d+\.\d+\.\d+)(?!\d)')
if (-not $openSpecVersionMatch.Success) {
    throw "Could not parse the OpenSpec version from: '$openSpecVersionText'."
}
try {
    $openSpecVersion = [version]$openSpecVersionMatch.Groups[1].Value
} catch {
    throw "Could not parse the OpenSpec version from: '$openSpecVersionText'."
}
if ($openSpecVersion -lt $RequiredOpenSpecVersion) {
    throw "OpenSpec $RequiredOpenSpecVersion or newer is required; found $openSpecVersion."
}
if ($openSpecVersion.Major -ne $SupportedOpenSpecMajor) {
    throw "OpenSpec major version $($openSpecVersion.Major) is not supported; install a compatible $SupportedOpenSpecMajor.x release."
}

foreach ($legacyPath in @(('.' + 'specify'), ('.github/skills/' + 'spec' + 'kit-specify'))) {
    if (Test-Path -LiteralPath (Join-Path $targetRoot $legacyPath)) {
        throw "An active legacy SDD path exists at '$legacyPath'. Preserve and migrate it before installing OpenSpec."
    }
}

$payload = [System.Collections.Generic.List[object]]::new()
function Add-Payload([string]$Source, [string]$Destination) {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Package payload is missing: $Source"
    }
    $payload.Add([pscustomobject]@{
        Source = [IO.Path]::GetFullPath($Source)
        Destination = [IO.Path]::GetFullPath($Destination)
    })
}

function Add-PayloadTree([string]$SourceRoot, [string]$DestinationRoot) {
    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        throw "Package payload directory is missing: $SourceRoot"
    }
    foreach ($file in Get-ChildItem -LiteralPath $SourceRoot -Recurse -File) {
        $relative = $file.FullName.Substring($SourceRoot.Length).TrimStart('\', '/')
        Add-Payload $file.FullName (Join-Path $DestinationRoot $relative)
    }
}

Add-PayloadTree (Join-Path $packageRoot 'schema') (Join-Path $targetRoot 'openspec/schemas/dotnet-sdd')
Add-Payload (Join-Path $packageRoot 'config/config.yaml') (Join-Path $targetRoot 'openspec/config.yaml')
Add-Payload (Join-Path $packageRoot 'docs/dotnet-sdd-governance.md') (Join-Path $targetRoot 'docs/architecture/dotnet-sdd-governance.md')
Add-PayloadTree (Join-Path $packageRoot 'tools/dotnet-sdd-guard') (Join-Path $targetRoot 'tools/dotnet-sdd-guard')
Add-PayloadTree (Join-Path $packageRoot 'scripts') (Join-Path $targetRoot 'scripts')

if ('codex' -in $Tools) {
    Add-Payload (Join-Path $packageRoot 'skills/codex/dotnet-sdd-verify/SKILL.md') (Join-Path $targetRoot '.codex/skills/dotnet-sdd-verify/SKILL.md')
    Add-Payload (Join-Path $packageRoot 'skills/codex/dotnet-sdd-verify/agents/openai.yaml') (Join-Path $targetRoot '.codex/skills/dotnet-sdd-verify/agents/openai.yaml')
}
if ('github-copilot' -in $Tools) {
    Add-Payload (Join-Path $packageRoot 'skills/github-copilot/dotnet-sdd-verify/SKILL.md') (Join-Path $targetRoot '.github/skills/dotnet-sdd-verify/SKILL.md')
}

$forbiddenPayloadPatterns = @(
    'ghp_[A-Za-z0-9]{20,}',
    'github_pat_[A-Za-z0-9_]{20,}',
    '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    '(?i)(?:password|clientsecret|accountkey)\s*[:=]\s*["''][^"'']{8,}["'']',
    ('[A-Za-z]:' + '\\Users\\[A-Za-z0-9._-]+\\'),
    ('[A-Za-z]:' + '/Users/[A-Za-z0-9._-]+/'),
    ('file' + '://'),
    ('local' + 'host'),
    ('127' + '\.0\.0\.1'),
    ('\[' + '::1\]')
)
foreach ($item in $payload) {
    if ([IO.Path]::GetExtension($item.Source) -notin @('.md', '.ps1', '.yaml', '.yml')) { continue }
    $content = Get-Content -LiteralPath $item.Source -Raw
    foreach ($pattern in $forbiddenPayloadPatterns) {
        if ($content -match $pattern) {
            $relativeSource = $item.Source.Substring($packageRoot.Length + 1)
            throw "Package payload contains a forbidden secret or local-environment marker: $relativeSource"
        }
    }
}

$preexistingDestinations = @{}
foreach ($item in $payload) {
    $preexistingDestinations[$item.Destination] = Test-Path -LiteralPath $item.Destination -PathType Leaf
}
$collisions = @($payload | Where-Object {
    $preexistingDestinations[$_.Destination] -and
    (Get-FileHash -LiteralPath $_.Source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $_.Destination -Algorithm SHA256).Hash
})
if ($collisions.Count -gt 0 -and -not $BackupExisting) {
    $paths = $collisions | ForEach-Object { $_.Destination.Substring($targetRoot.Length + 1) }
    throw "Installation would overwrite $($collisions.Count) differing file(s): $($paths -join ', '). Re-run with -BackupExisting after review. No files were modified."
}

$toolArgument = $Tools -join ','
$hasOpenSpecConfig = Test-Path -LiteralPath (Join-Path $targetRoot 'openspec/config.yaml') -PathType Leaf
Push-Location -LiteralPath $targetRoot
try {
    if ($hasOpenSpecConfig) {
        & $openSpecCommand.Source update --force
    } else {
        & $openSpecCommand.Source init . --tools $toolArgument --force --no-animation
    }
    if ($LASTEXITCODE -ne 0) { throw 'OpenSpec tool integration generation failed.' }
}
finally {
    Pop-Location
}

$backupStamp = Get-Date -Format 'yyyyMMddHHmmssfff'
foreach ($item in $payload) {
    $destinationDirectory = Split-Path -Parent $item.Destination
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    if (Test-Path -LiteralPath $item.Destination -PathType Leaf) {
        $same = (Get-FileHash -LiteralPath $item.Source -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $item.Destination -Algorithm SHA256).Hash
        if ($same) { continue }
        if ($preexistingDestinations[$item.Destination]) {
            if (-not $BackupExisting) {
                throw "A payload collision appeared after preflight: $($item.Destination). No overwrite was performed."
            }
            Copy-Item -LiteralPath $item.Destination -Destination "$($item.Destination).backup-$backupStamp"
        }
    }
    Copy-Item -LiteralPath $item.Source -Destination $item.Destination -Force
}

$specFiles = @(
    foreach ($relativeRoot in @('openspec/specs', 'openspec/changes')) {
        $candidate = Join-Path $targetRoot $relativeRoot
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            Get-ChildItem -LiteralPath $candidate -Recurse -File -ErrorAction SilentlyContinue
        }
    }
)
Push-Location -LiteralPath $targetRoot
try {
    & $openSpecCommand.Source schema validate dotnet-sdd --verbose
    if ($LASTEXITCODE -ne 0) { throw 'Installed dotnet-sdd schema is invalid.' }
    if ($specFiles.Count -gt 0) {
        & $openSpecCommand.Source validate --all --strict
        if ($LASTEXITCODE -ne 0) { throw 'Strict validation of the consumer OpenSpec artifacts failed.' }
    }
}
finally {
    Pop-Location
}

Write-Output "Installed dotnet-sdd 2.0.0 into $targetRoot"
Write-Output "Node.js: $nodeText; OpenSpec: $openSpecVersion; tools: $toolArgument"
Write-Output 'Next: openspec validate --all --strict'
Write-Output 'Next change: use $openspec-propose in Codex or /opsx-propose in GitHub Copilot.'
