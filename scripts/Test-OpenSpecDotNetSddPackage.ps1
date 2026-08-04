[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$package = Join-Path $root 'distribution/openspec/dotnet-sdd'
$minimumOpenSpec = [version]'1.7.0'

function Invoke-RequiredCommand {
    param([string]$Label, [scriptblock]$Command)
    Write-Output "== $Label =="
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

function Assert-SameFile {
    param([string]$Left, [string]$Right)
    if (-not (Test-Path -LiteralPath $Left -PathType Leaf)) { throw "Missing root file: $Left" }
    if (-not (Test-Path -LiteralPath $Right -PathType Leaf)) { throw "Missing distribution file: $Right" }
    $leftHash = (Get-FileHash -LiteralPath $Left -Algorithm SHA256).Hash
    $rightHash = (Get-FileHash -LiteralPath $Right -Algorithm SHA256).Hash
    if ($leftHash -ne $rightHash) {
        throw "Root and distribution copies differ: $Left <> $Right"
    }
}

function Assert-SameTree {
    param([string]$LeftRoot, [string]$RightRoot)
    $leftFiles = @(Get-ChildItem -LiteralPath $LeftRoot -Recurse -File | ForEach-Object {
        $_.FullName.Substring($LeftRoot.Length).TrimStart('\', '/').Replace('\', '/')
    } | Sort-Object)
    $rightFiles = @(Get-ChildItem -LiteralPath $RightRoot -Recurse -File | ForEach-Object {
        $_.FullName.Substring($RightRoot.Length).TrimStart('\', '/').Replace('\', '/')
    } | Sort-Object)
    if (($leftFiles -join "`n") -ne ($rightFiles -join "`n")) {
        throw "Root and distribution trees contain different files: $LeftRoot <> $RightRoot"
    }
    foreach ($relative in $leftFiles) {
        Assert-SameFile (Join-Path $LeftRoot $relative) (Join-Path $RightRoot $relative)
    }
}

if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "Repository root does not exist: $root" }
if (-not (Test-Path -LiteralPath $package -PathType Container)) { throw 'Distribution package is missing.' }

$openSpec = Get-Command openspec -ErrorAction SilentlyContinue
if (-not $openSpec) { throw 'OpenSpec CLI is required.' }
$versionText = (& $openSpec.Source --version 2>&1 | Out-String).Trim()
$versionMatch = [regex]::Match($versionText, '(?<!\d)(\d+\.\d+\.\d+)(?!\d)')
if (-not $versionMatch.Success) { throw "Could not parse OpenSpec version from '$versionText'." }
$openSpecVersion = [version]$versionMatch.Groups[1].Value
if ($openSpecVersion -lt $minimumOpenSpec -or $openSpecVersion.Major -ne 1) {
    throw "OpenSpec 1.x at or above $minimumOpenSpec is required; found $openSpecVersion."
}

$requiredFiles = @(
    'openspec/config.yaml',
    'openspec/schemas/dotnet-sdd/schema.yaml',
    'openspec/schemas/dotnet-sdd/templates/proposal.md',
    'openspec/schemas/dotnet-sdd/templates/spec.md',
    'openspec/schemas/dotnet-sdd/templates/research.md',
    'openspec/schemas/dotnet-sdd/templates/design.md',
    'openspec/schemas/dotnet-sdd/templates/review.md',
    'openspec/schemas/dotnet-sdd/templates/tasks.md',
    'docs/architecture/dotnet-sdd-governance.md',
    'tools/dotnet-sdd-guard/Invoke-DotNetSddGuard.ps1',
    'tools/dotnet-sdd-guard/tests/Invoke-GuardTests.ps1',
    'distribution/openspec/dotnet-sdd/install.ps1',
    'distribution/openspec/dotnet-sdd/tests/Invoke-InstallerTests.ps1'
)
foreach ($relative in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf)) {
        throw "Required package file is missing: $relative"
    }
}

$removedApplicationPath = 'PoC' + 'Final'
$removedCapabilityPath = 'contact' + '-requests'
$removedHistoryPath = '001-' + 'registrar' + '-contacto'
foreach ($relative in @($removedApplicationPath, "openspec/specs/$removedCapabilityPath", "docs/sdd-history/spec-kit/$removedHistoryPath")) {
    if (Test-Path -LiteralPath (Join-Path $root $relative)) {
        throw "Removed application or capability path still exists: $relative"
    }
}

Push-Location -LiteralPath $root
try {
    Invoke-RequiredCommand 'OpenSpec schemas' { & $openSpec.Source schemas }
    Invoke-RequiredCommand 'OpenSpec schema resolution' { & $openSpec.Source schema which dotnet-sdd }
    Invoke-RequiredCommand 'OpenSpec schema validation' { & $openSpec.Source schema validate dotnet-sdd --verbose }
    Invoke-RequiredCommand 'OpenSpec templates' { & $openSpec.Source templates --schema dotnet-sdd }
    Invoke-RequiredCommand 'OpenSpec strict validation' { & $openSpec.Source validate --all --strict }

    Assert-SameFile (Join-Path $root 'openspec/config.yaml') (Join-Path $package 'config/config.yaml')
    Assert-SameTree (Join-Path $root 'openspec/schemas/dotnet-sdd') (Join-Path $package 'schema')
    Assert-SameFile (Join-Path $root 'docs/architecture/dotnet-sdd-governance.md') (Join-Path $package 'docs/dotnet-sdd-governance.md')
    Assert-SameFile (Join-Path $root 'tools/dotnet-sdd-guard/Invoke-DotNetSddGuard.ps1') (Join-Path $package 'tools/dotnet-sdd-guard/Invoke-DotNetSddGuard.ps1')
    Assert-SameFile (Join-Path $root '.codex/skills/dotnet-sdd-verify/SKILL.md') (Join-Path $package 'skills/codex/dotnet-sdd-verify/SKILL.md')
    Assert-SameFile (Join-Path $root '.github/skills/dotnet-sdd-verify/SKILL.md') (Join-Path $package 'skills/github-copilot/dotnet-sdd-verify/SKILL.md')
    Write-Output 'PASS root and distribution copies are consistent.'

    $tracked = @(& git ls-files --cached --others --exclude-standard)
    if ($LASTEXITCODE -ne 0) { throw 'Could not enumerate repository files.' }
    $textExtensions = @('.cs', '.csproj', '.props', '.targets', '.json', '.yaml', '.yml', '.ps1', '.md', '.txt')
    $textFiles = @($tracked | Where-Object {
        $_ -notmatch '^legacy/spec-kit/' -and
        [IO.Path]::GetExtension($_) -in $textExtensions
    })

    $removedMarkers = @(
        ('PoC' + 'Final'),
        ('Contact' + 'Requests'),
        ('contact' + '-requests'),
        ('registrar' + '-contacto'),
        ('solicitud' + ' de contacto'),
        ('HU' + '-001')
    )
    $legacyRuntimeMarkers = @(
        ('spec' + 'ify-cli'),
        ('\.' + 'spec' + 'ify'),
        ('spec' + 'kit\.')
    )
    $localPatterns = @(
        ('[A-Za-z]:' + '\\Users\\[A-Za-z0-9._-]+\\'),
        ('[A-Za-z]:' + '/Users/[A-Za-z0-9._-]+/'),
        ('file' + '://'),
        ('local' + 'host'),
        ('127' + '\.0\.0\.1'),
        ('\[' + '::1\]')
    )
    $secretPatterns = @(
        'ghp_[A-Za-z0-9]{20,}',
        'github_pat_[A-Za-z0-9_]{20,}',
        '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
        '(?i)(?:password|clientsecret|accountkey)\s*[:=]\s*["''][^"'']{8,}["'']'
    )

    $violations = [System.Collections.Generic.List[string]]::new()
    foreach ($relative in $textFiles) {
        $content = Get-Content -LiteralPath (Join-Path $root $relative) -Raw -ErrorAction SilentlyContinue
        foreach ($pattern in $removedMarkers + $legacyRuntimeMarkers + $localPatterns + $secretPatterns) {
            if ($content -match $pattern) {
                $violations.Add($relative)
                break
            }
        }
    }
    if ($violations.Count -gt 0) {
        throw "Active package audit found forbidden content in: $(@($violations | Sort-Object -Unique) -join ', ')"
    }
    Write-Output "PASS active reference, secret, and local-path audit across $($textFiles.Count) repository text files."

    $powerShell = (Get-Process -Id $PID).Path
    Invoke-RequiredCommand 'Guard fixture tests' {
        & $powerShell -NoProfile -File (Join-Path $root 'tools/dotnet-sdd-guard/tests/Invoke-GuardTests.ps1')
    }
    Invoke-RequiredCommand 'Installer fixture tests' {
        & $powerShell -NoProfile -File (Join-Path $package 'tests/Invoke-InstallerTests.ps1')
    }
}
finally {
    Pop-Location
}

Write-Output "PACKAGE VALIDATION PASS: OpenSpec $openSpecVersion"
exit 0
