[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$harness = (Resolve-Path (Join-Path $PSScriptRoot '../Invoke-OpenSpecEvaluation.ps1')).Path
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase ("openspec-sdd-harness-tests-" + [guid]::NewGuid().ToString('N'))
$script:Passed = 0
$script:Failed = 0

function Invoke-Test([string]$Name, [scriptblock]$Body) {
    try { & $Body; $script:Passed++; Write-Output "PASS $Name" }
    catch { $script:Failed++; Write-Output "FAIL $Name - $($_.Exception.Message)" }
}

function New-Fixture([string]$Name, [string]$GuardResult = 'PASS') {
    $root = Join-Path $tempRoot $Name
    New-Item -ItemType Directory -Path (Join-Path $root 'openspec'), (Join-Path $root 'scripts'), (Join-Path $root 'PoCFinal/artifacts/sdd-guard') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $root 'openspec/config.yaml') -Value 'schema: dotnet-sdd' -Encoding utf8NoBOM
    @{ result = $GuardResult } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'PoCFinal/artifacts/sdd-guard/guard-result.json') -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $root 'PoCFinal/artifacts/sdd-guard/guard-result.md') -Value "# $GuardResult" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $root 'fake-openspec.ps1') -Value 'param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Rest); exit 0' -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $root 'scripts/fake-guard.ps1') -Value 'param([string]$RepositoryRoot); exit 0' -Encoding utf8NoBOM
    return $root
}

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    Invoke-Test 'accepted evaluation records relative evidence' {
        $root = New-Fixture 'accepted'
        & $harness -ProjectRoot $root -EvaluationId 'run-001' -OpenSpecCommand (Join-Path $root 'fake-openspec.ps1') -GuardScript (Join-Path $root 'scripts/fake-guard.ps1') *> $null
        if ($LASTEXITCODE -ne 0) { throw "exit $LASTEXITCODE" }
        $record = Get-Content -LiteralPath (Join-Path $root 'artifacts/sdd-evaluation/run-001/evaluation.json') -Raw | ConvertFrom-Json
        if ($record.result -ne 'accepted' -or $record.evidence.guardJson -match '^[A-Za-z]:') { throw 'invalid accepted record' }
    }
    Invoke-Test 'evaluation IDs cannot overwrite prior evidence' {
        $root = Join-Path $tempRoot 'accepted'
        $threw = $false
        try { & $harness -ProjectRoot $root -EvaluationId 'run-001' -OpenSpecCommand (Join-Path $root 'fake-openspec.ps1') -GuardScript (Join-Path $root 'scripts/fake-guard.ps1') *> $null } catch { $threw = $true }
        if (-not $threw) { throw 'duplicate evaluation was accepted' }
    }
    Invoke-Test 'non-pass guard result fails evaluation' {
        $root = New-Fixture 'failed' 'FAIL'
        & $harness -ProjectRoot $root -EvaluationId 'run-002' -OpenSpecCommand (Join-Path $root 'fake-openspec.ps1') -GuardScript (Join-Path $root 'scripts/fake-guard.ps1') *> $null
        if ($LASTEXITCODE -ne 1) { throw "expected exit 1, got $LASTEXITCODE" }
        $record = Get-Content -LiteralPath (Join-Path $root 'artifacts/sdd-evaluation/run-002/evaluation.json') -Raw | ConvertFrom-Json
        if ($record.result -ne 'failed') { throw 'failed result was not recorded' }
    }
    Invoke-Test 'records do not persist secret fixture content' {
        $root = Join-Path $tempRoot 'accepted'
        Set-Content -LiteralPath (Join-Path $root 'secret-input.txt') -Value 'super-secret-value' -Encoding utf8NoBOM
        $recordText = Get-Content -LiteralPath (Join-Path $root 'artifacts/sdd-evaluation/run-001/evaluation.json') -Raw
        if ($recordText -match 'super-secret-value' -or $recordText -match [regex]::Escape($root)) { throw 'sensitive or absolute data leaked' }
    }
} finally {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if ($resolved.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

if ($script:Failed -gt 0) { throw "HARNESS TESTS FAILED: passed=$($script:Passed) failed=$($script:Failed)" }
Write-Output "ALL HARNESS TESTS PASS: passed=$($script:Passed) failed=0"
exit 0
