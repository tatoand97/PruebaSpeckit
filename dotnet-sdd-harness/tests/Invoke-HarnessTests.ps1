[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$export = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/Export-SddAcceptanceReport.ps1')).Path
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("dotnet-sdd-harness-tests-" + [guid]::NewGuid().ToString('N'))
$script:Passed = 0
$script:Failed = 0

function Write-Json {
    param([string]$Path, [object]$Value)
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    $Value | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

function New-EvaluationFixture {
    param([string]$Name, [string]$Status, [string]$GuardResult, [switch]$RejectGate, [switch]$NoGuard)
    $root = Join-Path $tempRoot $Name
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    Write-Json (Join-Path $root 'artifacts/sdd-evaluation/evaluation.json') ([ordered]@{
        schemaVersion='1.0'; scenarioId=$Name; workflowId='dotnet-sdd-feature'; integration='copilot'; runId='run123'; status='started'
    })
    $gateStatus = if ($RejectGate) { 'failed' } elseif ($Status -eq 'paused') { 'paused' } else { 'completed' }
    Write-Json (Join-Path $root '.specify/workflows/runs/run123/state.json') ([ordered]@{
        run_id='run123'; workflow_id='dotnet-sdd-feature'; status=$Status; created_at='2026-01-01T00:00:00Z'; updated_at='2026-01-01T00:01:00Z'
        step_results=[ordered]@{
            specify=[ordered]@{ type='command'; status='completed' }
            'review-spec'=[ordered]@{ type='gate'; status=$gateStatus; output=[ordered]@{ aborted=[bool]$RejectGate } }
            analyze=[ordered]@{ type='command'; status='completed' }
            converge=[ordered]@{ type='command'; status='completed' }
        }
    })
    New-Item -ItemType Directory -Path (Join-Path $root '.specify/workflows/runs/run123') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $root '.specify/workflows/runs/run123/log.jsonl') -Value '{"event":"step_completed","status":"paused"}' -Encoding utf8NoBOM
    if (-not $NoGuard) {
        Write-Json (Join-Path $root 'artifacts/sdd-guard/guard-result.json') ([ordered]@{
            schemaVersion='1.0'; guard=[ordered]@{ id='dotnet-sdd-guard'; version='1.0.0' }; result=$GuardResult
            checks=@(
                [ordered]@{ id='ARCH001'; status='PASS'; evidence='No prohibited edges.' },
                [ordered]@{ id='BUILD001'; status='PASS'; evidence='warningCount=0' },
                [ordered]@{ id='TEST001'; status='PASS'; evidence='executed=3; passed=3; failed=0; skipped=0' },
                [ordered]@{ id='COV001'; status='PASS'; evidence='lineCoveragePercent=85' },
                [ordered]@{ id='OPENAPI001'; status='PASS'; evidence='one contract' }
            )
            summary=[ordered]@{ passed=5; failed=if($GuardResult -eq 'FAIL'){1}else{0}; advisory=0; notApplicable=0 }
        })
    }
    return $root
}

function Assert-Result {
    param([string]$Name, [string]$Status, [string]$Guard, [string]$Expected, [switch]$Reject, [switch]$NoGuard)
    try {
        $root = New-EvaluationFixture $Name $Status $Guard -RejectGate:$Reject -NoGuard:$NoGuard
        & $export -ProjectRoot $root *> $null
        $report = Get-Content -LiteralPath (Join-Path $root 'artifacts/sdd-evaluation/sdd-acceptance.json') -Raw | ConvertFrom-Json
        if ($report.result -ne $Expected) { throw "expected=$Expected actual=$($report.result)" }
        $script:Passed++; Write-Output "PASS $Name"
    } catch {
        $script:Failed++; Write-Output "FAIL $Name - $($_.Exception.Message)"
    }
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    Assert-Result 'completed-pass' 'completed' 'PASS' 'ACCEPTED'
    Assert-Result 'completed-fail' 'completed' 'FAIL' 'FAILED'
    Assert-Result 'paused' 'paused' 'PASS' 'INCOMPLETE'
    Assert-Result 'rejected-gate' 'aborted' 'PASS' 'REJECTED' -Reject
    Assert-Result 'missing-guard-completed' 'completed' '' 'FAILED' -NoGuard
    Assert-Result 'missing-guard-paused' 'paused' '' 'INCOMPLETE' -NoGuard

    $missing = New-EvaluationFixture 'missing-metric' 'completed' 'PASS'
    & $export -ProjectRoot $missing *> $null
    $missingReport = Get-Content (Join-Path $missing 'artifacts/sdd-evaluation/sdd-acceptance.json') -Raw | ConvertFrom-Json
    if ($missingReport.sdd.functionalRequirements -eq 'not_available' -and $missingReport.sdd.tasksAddedByConverge -eq 'not_available') {
        $script:Passed++; Write-Output 'PASS missing-metric'
    } else { $script:Failed++; Write-Output 'FAIL missing-metric' }

    $secret = New-EvaluationFixture 'sanitization' 'completed' 'PASS'
    New-Item -ItemType Directory -Path (Join-Path $secret 'specs/001') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $secret 'specs/001/spec.md') -Value @'
## User Story 1 - SecretCustomer
- **FR-001**: token=super-secret-token
C:\Users\Ricardo\source\repos\SecretProject
'@ -Encoding utf8NoBOM
    & $export -ProjectRoot $secret *> $null
    $exports = (Get-Content (Join-Path $secret 'artifacts/sdd-evaluation/sdd-acceptance.json') -Raw) +
        (Get-Content (Join-Path $secret 'artifacts/sdd-evaluation/sdd-acceptance.md') -Raw)
    if ($exports -notmatch 'SecretCustomer|super-secret-token|Ricardo|SecretProject|C:\\Users\\') {
        $script:Passed++; Write-Output 'PASS sanitization'
    } else { $script:Failed++; Write-Output 'FAIL sanitization' }

    $manual = New-EvaluationFixture 'manual-ai' 'completed' 'PASS'
    Write-Json (Join-Path $manual 'ai-usage.json') ([ordered]@{ source='manual'; totalTokens=123; note='super-secret-token' })
    & $export -ProjectRoot $manual -AiUsagePath (Join-Path $manual 'ai-usage.json') *> $null
    $manualRaw = Get-Content (Join-Path $manual 'artifacts/sdd-evaluation/sdd-acceptance.json') -Raw
    $manualReport = $manualRaw | ConvertFrom-Json
    if ($manualReport.aiUsage.source -eq 'manual' -and $manualReport.aiUsage.totalTokens -eq 123 -and $manualRaw -notmatch 'super-secret-token') {
        $script:Passed++; Write-Output 'PASS manual-ai-usage'
    } else { $script:Failed++; Write-Output 'FAIL manual-ai-usage' }

    if ($script:Failed -gt 0) {
        Write-Output "HARNESS TESTS FAILED: passed=$script:Passed failed=$script:Failed"
        exit 1
    }
    Write-Output "ALL HARNESS TESTS PASS: $script:Passed"
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
