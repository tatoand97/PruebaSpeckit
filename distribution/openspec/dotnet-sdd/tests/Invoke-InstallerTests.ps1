[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $packageRoot 'install.ps1'
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $tempBase ("dotnet-sdd-openspec-tests-" + [guid]::NewGuid().ToString('N'))
$script:Passed = 0
$script:Failed = 0

function Invoke-Test([string]$Name, [scriptblock]$Body) {
    try {
        & $Body
        $script:Passed++
        Write-Output "PASS $Name"
    } catch {
        $script:Failed++
        Write-Output "FAIL $Name - $($_.Exception.Message)"
    }
}

function New-Target([string]$Name) {
    $path = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Invoke-WithOpenSpecMock {
    param(
        [string]$Name,
        [string]$VersionText,
        [scriptblock]$Body
    )

    $mockRoot = Join-Path $testRoot "mock-$Name"
    New-Item -ItemType Directory -Path $mockRoot -Force | Out-Null
    $logPath = Join-Path $mockRoot 'invocations.log'
    $mock = @"
@echo off
if "%1"=="--version" (
  echo $VersionText
  exit /b 0
)
echo %*>>"$logPath"
exit /b 0
"@
    Set-Content -LiteralPath (Join-Path $mockRoot 'openspec.cmd') -Value $mock -Encoding ascii
    $originalPath = [Environment]::GetEnvironmentVariable('PATH', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('PATH', "$mockRoot;$originalPath", 'Process')
        & $Body $logPath
    }
    finally {
        [Environment]::SetEnvironmentVariable('PATH', $originalPath, 'Process')
    }
}

New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
try {
    $clean = New-Target 'clean'
    Invoke-Test 'clean install creates config, governance, schema, tools, and skills' {
        & $installer -ProjectPath $clean -Tools codex,github-copilot
        if ($LASTEXITCODE -ne 0) { throw "installer exit $LASTEXITCODE" }
        foreach ($relative in @(
            'openspec/config.yaml',
            'openspec/schemas/dotnet-sdd/schema.yaml',
            'docs/architecture/dotnet-sdd-governance.md',
            'tools/dotnet-sdd-guard/Invoke-DotNetSddGuard.ps1',
            'tools/dotnet-sdd-guard/README.md',
            'scripts/Invoke-OpenSpecSddGuard.ps1',
            '.codex/skills/dotnet-sdd-verify/SKILL.md',
            '.github/skills/dotnet-sdd-verify/SKILL.md'
        )) {
            if (-not (Test-Path -LiteralPath (Join-Path $clean $relative) -PathType Leaf)) { throw "missing $relative" }
        }
        if ((Get-Content -LiteralPath (Join-Path $clean 'openspec/config.yaml') -Raw) -notmatch '(?m)^schema:\s*dotnet-sdd\s*$') {
            throw 'dotnet-sdd was not selected in config.yaml'
        }
        $distributedConfig = Get-Content -LiteralPath (Join-Path $clean 'openspec/config.yaml') -Raw
        $removedApplicationMarker = 'PoC' + 'Final'
        if ($distributedConfig -match $removedApplicationMarker -or $distributedConfig -match '[A-Za-z]:[\\/]Users[\\/]') {
            throw 'installed config is not reusable'
        }
    }

    Invoke-Test 'reinstallation is idempotent' {
        $tracked = @(
            'openspec/config.yaml',
            'openspec/schemas/dotnet-sdd/schema.yaml',
            'docs/architecture/dotnet-sdd-governance.md'
        )
        $before = @{}
        foreach ($relative in $tracked) {
            $before[$relative] = (Get-FileHash -LiteralPath (Join-Path $clean $relative) -Algorithm SHA256).Hash
        }
        & $installer -ProjectPath $clean -Tools codex,github-copilot
        if ($LASTEXITCODE -ne 0) { throw "installer exit $LASTEXITCODE" }
        foreach ($relative in $tracked) {
            $after = (Get-FileHash -LiteralPath (Join-Path $clean $relative) -Algorithm SHA256).Hash
            if ($before[$relative] -ne $after) { throw "$relative changed during idempotent reinstall" }
        }
        if (@(Get-ChildItem -LiteralPath $clean -Recurse -File -Filter '*.backup-*').Count -ne 0) { throw 'idempotent reinstall created a backup' }
    }

    Invoke-Test 'differing collision is rejected before overwrite' {
        $collision = New-Target 'collision'
        $path = Join-Path $collision '.codex/skills/dotnet-sdd-verify/SKILL.md'
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        Set-Content -LiteralPath $path -Value 'user-authored' -Encoding utf8NoBOM
        $threw = $false
        try { & $installer -ProjectPath $collision -Tools codex } catch { $threw = $true }
        if (-not $threw) { throw 'collision was not rejected' }
        if ((Get-Content -LiteralPath $path -Raw).Trim() -ne 'user-authored') { throw 'collision content was overwritten' }
    }

    Invoke-Test 'configuration collision is rejected without partial installation' {
        $collision = New-Target 'config-collision'
        $path = Join-Path $collision 'openspec/config.yaml'
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        Set-Content -LiteralPath $path -Value 'schema: another-schema' -Encoding utf8NoBOM
        $threw = $false
        try { & $installer -ProjectPath $collision -Tools codex } catch { $threw = $true }
        if (-not $threw) { throw 'configuration collision was not rejected' }
        if ((Get-Content -LiteralPath $path -Raw).Trim() -ne 'schema: another-schema') { throw 'configuration collision was overwritten' }
        if (Test-Path -LiteralPath (Join-Path $collision 'docs/architecture/dotnet-sdd-governance.md')) { throw 'partial installation occurred after configuration collision' }
    }

    Invoke-Test 'governance collision is rejected without partial installation' {
        $collision = New-Target 'governance-collision'
        $path = Join-Path $collision 'docs/architecture/dotnet-sdd-governance.md'
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        Set-Content -LiteralPath $path -Value 'consumer governance' -Encoding utf8NoBOM
        $threw = $false
        try { & $installer -ProjectPath $collision -Tools codex } catch { $threw = $true }
        if (-not $threw) { throw 'governance collision was not rejected' }
        if ((Get-Content -LiteralPath $path -Raw).Trim() -ne 'consumer governance') { throw 'governance collision was overwritten' }
        if (Test-Path -LiteralPath (Join-Path $collision 'openspec/config.yaml')) { throw 'partial installation occurred after governance collision' }
    }

    Invoke-Test 'BackupExisting backs up and replaces config and governance' {
        $target = New-Target 'backup-existing'
        $configPath = Join-Path $target 'openspec/config.yaml'
        $governancePath = Join-Path $target 'docs/architecture/dotnet-sdd-governance.md'
        New-Item -ItemType Directory -Path (Split-Path -Parent $configPath) -Force | Out-Null
        New-Item -ItemType Directory -Path (Split-Path -Parent $governancePath) -Force | Out-Null
        Set-Content -LiteralPath $configPath -Value 'schema: another-schema' -Encoding utf8NoBOM
        Set-Content -LiteralPath $governancePath -Value 'consumer governance' -Encoding utf8NoBOM
        Invoke-WithOpenSpecMock -Name 'backup' -VersionText '1.7.0' -Body {
            param($log)
            & $installer -ProjectPath $target -Tools codex -BackupExisting
        }
        if ((Get-Content -LiteralPath $configPath -Raw) -notmatch '(?m)^schema:\s*dotnet-sdd\s*$') { throw 'config was not replaced' }
        if ((Get-Content -LiteralPath $governancePath -Raw) -notmatch '^# Repository \.NET SDD Governance') { throw 'governance was not replaced' }
        $configBackup = @(Get-ChildItem -LiteralPath (Split-Path -Parent $configPath) -Filter 'config.yaml.backup-*')
        $governanceBackup = @(Get-ChildItem -LiteralPath (Split-Path -Parent $governancePath) -Filter 'dotnet-sdd-governance.md.backup-*')
        if ($configBackup.Count -ne 1 -or (Get-Content -LiteralPath $configBackup[0].FullName -Raw).Trim() -ne 'schema: another-schema') { throw 'config backup is missing or incorrect' }
        if ($governanceBackup.Count -ne 1 -or (Get-Content -LiteralPath $governanceBackup[0].FullName -Raw).Trim() -ne 'consumer governance') { throw 'governance backup is missing or incorrect' }
    }

    Invoke-Test 'incompatible and unparseable OpenSpec versions are rejected' {
        foreach ($case in @(
            @{ Name = 'too-old'; Version = '1.6.9' },
            @{ Name = 'unsupported-major'; Version = '2.0.0' },
            @{ Name = 'unparseable'; Version = 'development-build' }
        )) {
            $target = New-Target "version-$($case.Name)"
            $threw = $false
            try {
                Invoke-WithOpenSpecMock -Name $case.Name -VersionText $case.Version -Body {
                    param($log)
                    & $installer -ProjectPath $target -Tools codex
                }
            } catch {
                $threw = $true
            }
            if (-not $threw) { throw "OpenSpec version '$($case.Version)' was accepted" }
            if (@(Get-ChildItem -LiteralPath $target -Force).Count -ne 0) { throw "version rejection modified target $($case.Name)" }
        }
    }

    Invoke-Test 'consumer artifacts trigger strict validation after installation' {
        $target = New-Target 'strict-validation'
        $configPath = Join-Path $target 'openspec/config.yaml'
        $specPath = Join-Path $target 'openspec/specs/example/spec.md'
        New-Item -ItemType Directory -Path (Split-Path -Parent $configPath) -Force | Out-Null
        New-Item -ItemType Directory -Path (Split-Path -Parent $specPath) -Force | Out-Null
        Set-Content -LiteralPath $configPath -Value (Get-Content -LiteralPath (Join-Path $packageRoot 'config/config.yaml') -Raw) -Encoding utf8NoBOM -NoNewline
        Set-Content -LiteralPath $specPath -Value '# Existing capability' -Encoding utf8NoBOM
        Invoke-WithOpenSpecMock -Name 'strict-validation' -VersionText '1.7.0' -Body {
            param($log)
            & $installer -ProjectPath $target -Tools codex
            $invocations = Get-Content -LiteralPath $log -Raw
            if ($invocations -notmatch '(?m)^validate --all --strict\s*$') { throw 'strict validation was not invoked' }
        }
    }

    Invoke-Test 'package contains no secret or local absolute path' {
        $files = @(Get-ChildItem -LiteralPath $packageRoot -Recurse -File | Where-Object { $_.Extension -in @('.md', '.ps1', '.yaml', '.yml') })
        foreach ($file in $files) {
            $text = Get-Content -LiteralPath $file.FullName -Raw
            $forbidden = @(
                'ghp_[A-Za-z0-9]{20,}',
                'github_pat_[A-Za-z0-9_]{20,}',
                '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
                ('[A-Za-z]:' + '\\Users\\[A-Za-z0-9._-]+\\'),
                ('[A-Za-z]:' + '/Users/[A-Za-z0-9._-]+/'),
                ('file' + '://'),
                ('local' + 'host'),
                ('127' + '\.0\.0\.1'),
                ('\[' + '::1\]')
            ) -join '|'
            if ($text -match $forbidden) {
                throw "forbidden marker in $($file.Name)"
            }
        }
    }

    Invoke-Test 'installer rejects every local-environment marker before modification' {
        $packageCopy = Join-Path $testRoot 'package-with-fixtures'
        Copy-Item -LiteralPath $packageRoot -Destination $packageCopy -Recurse
        $fixturePath = Join-Path $packageCopy 'docs/dotnet-sdd-governance.md'
        $markers = @(
            ('C:' + '\Users\installer-fixture\'),
            ('C:' + '/Users/installer-fixture/'),
            ('file' + '://'),
            ('local' + 'host'),
            ('127' + '.0.0.1'),
            ('[' + '::1]')
        )
        $index = 0
        foreach ($marker in $markers) {
            $index++
            Set-Content -LiteralPath $fixturePath -Value $marker -Encoding utf8NoBOM
            $target = New-Target "marker-$index"
            $threw = $false
            try { & (Join-Path $packageCopy 'install.ps1') -ProjectPath $target -Tools codex } catch { $threw = $true }
            if (-not $threw) { throw "marker $index was accepted" }
            if (@(Get-ChildItem -LiteralPath $target -Force).Count -ne 0) { throw "marker $index caused a partial installation" }
        }
    }

    Invoke-Test 'installed guard executes in a minimal fixture' {
        $fixture = New-Target 'guard-fixture'
        Set-Content -LiteralPath (Join-Path $fixture 'Fixture.sln') -Value '' -Encoding utf8NoBOM
        New-Item -ItemType Directory -Path (Join-Path $fixture 'src/Fixture.Domain') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fixture 'src/Fixture.Domain/Fixture.Domain.csproj') -Encoding utf8NoBOM -Value '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>'
        Set-Content -LiteralPath (Join-Path $fixture 'src/Fixture.Domain/Entity.cs') -Encoding utf8NoBOM -Value 'namespace Fixture.Domain; public sealed class Entity { public int Id { get; init; } }'
        New-Item -ItemType Directory -Path (Join-Path $fixture 'tests/Fixture.UnitTests') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fixture 'tests/Fixture.UnitTests/Fixture.UnitTests.csproj') -Encoding utf8NoBOM -Value '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>'
        $dotnetMock = Join-Path $fixture 'dotnet-mock.ps1'
        Set-Content -LiteralPath $dotnetMock -Encoding utf8NoBOM -Value @'
$command = if ($args.Count -gt 0) { $args[0] } else { '' }
if ($command -eq 'test') {
    $resultsDirectory = $null
    for ($index = 0; $index -lt $args.Count; $index++) {
        if ($args[$index] -eq '--results-directory') { $resultsDirectory = $args[$index + 1]; break }
    }
    New-Item -ItemType Directory -Path $resultsDirectory -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $resultsDirectory 'results.trx') -Encoding utf8 -Value '<?xml version="1.0"?><TestRun><ResultSummary><Counters executed="1" passed="1" failed="0" notExecuted="0" /></ResultSummary></TestRun>'
    Set-Content -LiteralPath (Join-Path $resultsDirectory 'coverage.cobertura.xml') -Encoding utf8 -Value '<?xml version="1.0"?><coverage><packages><package name="Fixture.Domain"><classes><class><lines><line number="1" hits="1" /></lines></class></classes></package></packages></coverage>'
}
exit 0
'@
        $previousMock = [Environment]::GetEnvironmentVariable('SDD_GUARD_DOTNET_PATH', 'Process')
        $evidenceRoot = Join-Path $fixture 'custom-evidence'
        try {
            [Environment]::SetEnvironmentVariable('SDD_GUARD_DOTNET_PATH', $dotnetMock, 'Process')
            & (Join-Path $clean 'tools/dotnet-sdd-guard/Invoke-DotNetSddGuard.ps1') -ProjectRoot $fixture -EvidencePath $evidenceRoot -VerboseDiagnostics
            if ($LASTEXITCODE -ne 0) {
                $report = Get-Content -LiteralPath (Join-Path $evidenceRoot 'guard-result.json') -Raw | ConvertFrom-Json
                $failedChecks = @($report.checks | Where-Object { $_.status -eq 'FAIL' } | ForEach-Object { $_.id }) -join ','
                throw "guard exit $LASTEXITCODE; result=$($report.result); failed=$failedChecks; configurationErrors=$($report.configurationErrors.Count)"
            }
        }
        finally {
            [Environment]::SetEnvironmentVariable('SDD_GUARD_DOTNET_PATH', $previousMock, 'Process')
        }
        if (-not (Test-Path -LiteralPath (Join-Path $evidenceRoot 'guard-result.json') -PathType Leaf)) {
            throw 'custom evidence output was not generated'
        }
        if (Test-Path -LiteralPath (Join-Path $fixture 'artifacts/sdd-guard/guard-result.json')) {
            throw 'default evidence location was used despite an explicit output path'
        }
    }
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if ($resolved.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

if ($script:Failed -gt 0) {
    throw "INSTALLER TESTS FAILED: passed=$($script:Passed) failed=$($script:Failed)"
}
Write-Output "ALL INSTALLER TESTS PASS: passed=$($script:Passed) failed=0"
