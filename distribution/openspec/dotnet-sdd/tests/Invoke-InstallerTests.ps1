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

New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
try {
    $clean = New-Target 'clean'
    Invoke-Test 'clean install creates OpenSpec schema, tools, and skills' {
        & $installer -ProjectPath $clean -Tools codex,github-copilot
        if ($LASTEXITCODE -ne 0) { throw "installer exit $LASTEXITCODE" }
        foreach ($relative in @(
            'openspec/config.yaml',
            'openspec/schemas/dotnet-sdd/schema.yaml',
            'tools/dotnet-sdd-guard/Invoke-DotNetSddGuard.ps1',
            'scripts/Invoke-OpenSpecSddGuard.ps1',
            '.codex/skills/dotnet-sdd-verify/SKILL.md',
            '.github/skills/dotnet-sdd-verify/SKILL.md'
        )) {
            if (-not (Test-Path -LiteralPath (Join-Path $clean $relative) -PathType Leaf)) { throw "missing $relative" }
        }
        if ((Get-Content -LiteralPath (Join-Path $clean 'openspec/config.yaml') -Raw) -notmatch '(?m)^schema:\s*dotnet-sdd\s*$') {
            throw 'dotnet-sdd was not selected in config.yaml'
        }
    }

    Invoke-Test 'reinstallation is idempotent' {
        $before = (Get-FileHash -LiteralPath (Join-Path $clean 'openspec/schemas/dotnet-sdd/schema.yaml') -Algorithm SHA256).Hash
        & $installer -ProjectPath $clean -Tools codex,github-copilot
        if ($LASTEXITCODE -ne 0) { throw "installer exit $LASTEXITCODE" }
        $after = (Get-FileHash -LiteralPath (Join-Path $clean 'openspec/schemas/dotnet-sdd/schema.yaml') -Algorithm SHA256).Hash
        if ($before -ne $after) { throw 'schema hash changed during idempotent reinstall' }
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

    Invoke-Test 'package contains no secret or local absolute path' {
        $files = @(Get-ChildItem -LiteralPath $packageRoot -Recurse -File | Where-Object { $_.Extension -in @('.md', '.ps1', '.yaml', '.yml') })
        foreach ($file in $files) {
            $text = Get-Content -LiteralPath $file.FullName -Raw
            if ($text -match 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|[A-Za-z]:\\Users\\[A-Za-z0-9._-]+\\') {
                throw "forbidden marker in $($file.Name)"
            }
        }
    }

    Invoke-Test 'installed guard executes in a minimal fixture' {
        $fixture = New-Target 'guard-fixture'
        Set-Content -LiteralPath (Join-Path $fixture 'Fixture.sln') -Value '' -Encoding utf8NoBOM
        New-Item -ItemType Directory -Path (Join-Path $fixture 'src/Fixture.Domain') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fixture 'src/Fixture.Domain/Fixture.Domain.csproj') -Encoding utf8NoBOM -Value '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>'
        Set-Content -LiteralPath (Join-Path $fixture 'src/Fixture.Domain/Entity.cs') -Encoding utf8NoBOM -Value 'namespace Fixture.Domain; public sealed class Entity { public int Id { get; init; } }'
        $evidence = @{ restore = $true; build = $true; tests = @{ ok = $true; counts = @{ executed = 1; passed = 1; failed = 0; skipped = 0 } }; coverage = 100; openapi = $true } | ConvertTo-Json -Depth 5
        Set-Content -LiteralPath (Join-Path $fixture 'evidence.json') -Value $evidence -Encoding utf8NoBOM
        & (Join-Path $clean 'tools/dotnet-sdd-guard/Invoke-DotNetSddGuard.ps1') -ProjectRoot $fixture -EvidencePath (Join-Path $fixture 'evidence.json')
        if ($LASTEXITCODE -ne 0) { throw "guard exit $LASTEXITCODE" }
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
