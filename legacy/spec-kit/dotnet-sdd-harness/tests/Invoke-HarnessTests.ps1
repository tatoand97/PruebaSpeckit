[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$start = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/Start-SddEvaluation.ps1')).Path
$attach = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/Attach-SddWorkflowRun.ps1')).Path
$get = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/Get-SddEvaluation.ps1')).Path
$export = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/Export-SddAcceptanceReport.ps1')).Path
$schema = (Resolve-Path (Join-Path $PSScriptRoot '../schemas/sdd-acceptance.schema.json')).Path
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("dotnet-sdd-harness-tests-" + [guid]::NewGuid().ToString('N'))
$script:Passed = 0
$script:Failed = 0

function Write-Json {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][object]$Value)

    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    $Value | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

function Assert-Equal {
    param([object]$Actual, [object]$Expected, [Parameter(Mandatory)][string]$Message)

    if ($Actual -ne $Expected) {
        throw "$Message expected='$Expected' actual='$Actual'"
    }
}

function Assert-True {
    param([bool]$Condition, [Parameter(Mandatory)][string]$Message)

    if (-not $Condition) { throw $Message }
}

function Invoke-HarnessTest {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Body)

    try {
        & $Body
        $script:Passed++
        Write-Output "PASS $Name"
    }
    catch {
        $script:Failed++
        Write-Output "FAIL $Name - $($_.Exception.Message)"
    }
}

function New-TestProject {
    param([Parameter(Mandatory)][string]$Name)

    $root = Join-Path $tempRoot $Name
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    return $root
}

function Start-TestEvaluation {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$ScenarioId = 'contact-request-v1',
        [string]$WorkflowId = 'dotnet-sdd-feature',
        [string]$Integration = 'codex'
    )

    & $start -ProjectRoot $Root -WorkflowId $WorkflowId -Integration $Integration -ScenarioId $ScenarioId
}

function Get-EvaluationDirectory {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$EvaluationId)

    Join-Path $Root "artifacts/sdd-evaluation/$EvaluationId"
}

function Write-WorkflowState {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$RunId,
        [string]$WorkflowId = 'dotnet-sdd-feature',
        [string]$Status = 'paused',
        [string]$Integration = 'codex',
        [ValidateSet('none', 'approve', 'reject')][string]$GateChoice = 'none',
        [switch]$IncidentShape
    )

    $steps = [ordered]@{
        specify = [ordered]@{
            type = 'command'
            integration = $Integration
            output = [ordered]@{ integration = $Integration }
            status = 'completed'
        }
    }
    if ($IncidentShape) {
        $steps.clarify = [ordered]@{
            type = 'command'
            integration = $Integration
            output = [ordered]@{ integration = $Integration }
            status = 'completed'
        }
    }
    if ($GateChoice -ne 'none' -or $IncidentShape) {
        $choice = if ($IncidentShape) { 'reject' } else { $GateChoice }
        $steps['review-spec'] = [ordered]@{
            type = 'gate'
            integration = $null
            output = [ordered]@{
                choice = $choice
                on_reject = 'abort'
                aborted = ($choice -eq 'reject')
            }
            status = if ($choice -eq 'reject') { 'failed' } elseif ($choice -eq 'approve') { 'completed' } else { 'paused' }
        }
    }
    if (-not $IncidentShape) {
        $steps.analyze = [ordered]@{ type = 'command'; integration = $Integration; status = 'completed' }
        $steps.converge = [ordered]@{ type = 'command'; integration = $Integration; status = 'completed' }
    }

    Write-Json (Join-Path $Root ".specify/workflows/runs/$RunId/state.json") ([ordered]@{
        run_id = $RunId
        workflow_id = $WorkflowId
        status = $Status
        current_step_id = if ($IncidentShape) { 'review-spec' } else { 'converge' }
        step_results = $steps
        created_at = '2026-01-01T00:00:00Z'
        updated_at = '2026-01-01T00:01:00Z'
    })
    Set-Content -LiteralPath (Join-Path $Root ".specify/workflows/runs/$RunId/log.jsonl") `
        -Value '{"event":"workflow_paused","status":"paused"}' -Encoding utf8NoBOM
}

function Write-GuardResult {
    param([Parameter(Mandatory)][string]$Root, [ValidateSet('PASS', 'FAIL', 'ERROR')][string]$Result)

    Write-Json (Join-Path $Root 'artifacts/sdd-guard/guard-result.json') ([ordered]@{
        schemaVersion = '1.0'
        guard = [ordered]@{ id = 'dotnet-sdd-guard'; version = '1.0.0' }
        result = $Result
        checks = @(
            [ordered]@{ id = 'ARCH001'; status = 'PASS'; evidence = 'No prohibited edges.' },
            [ordered]@{ id = 'BUILD001'; status = 'PASS'; evidence = 'warningCount=0' },
            [ordered]@{ id = 'TEST001'; status = 'PASS'; evidence = 'executed=3; passed=3; failed=0; skipped=0' },
            [ordered]@{ id = 'COV001'; status = 'PASS'; evidence = 'lineCoveragePercent=85' },
            [ordered]@{ id = 'OPENAPI001'; status = 'PASS'; evidence = 'one contract' }
        )
        summary = [ordered]@{
            passed = if ($Result -eq 'PASS') { 5 } else { 4 }
            failed = if ($Result -eq 'PASS') { 0 } else { 1 }
            advisory = 0
            notApplicable = 0
        }
    })
}

function Attach-TestRun {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$EvaluationId,
        [Parameter(Mandatory)][string]$RunId
    )

    & $attach -ProjectRoot $Root -EvaluationId $EvaluationId -RunId $RunId
}

function Export-AndRead {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$EvaluationId)

    & $export -ProjectRoot $Root -EvaluationId $EvaluationId *> $null
    Get-Content -LiteralPath (Join-Path (Get-EvaluationDirectory $Root $EvaluationId) 'sdd-acceptance.json') -Raw | ConvertFrom-Json
}

function Assert-ConfigurationError {
    param([Parameter(Mandatory)][scriptblock]$Body)

    try {
        & $Body
    }
    catch {
        if ($_.Exception.Message -match '^CONFIGURATION ERROR:') { return }
        throw "Expected CONFIGURATION ERROR, got: $($_.Exception.Message)"
    }
    throw 'Expected CONFIGURATION ERROR, but no error was thrown.'
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    Invoke-HarnessTest 'T01 start persists evaluation immediately' {
        $root = New-TestProject 't01-start'
        $evaluation = Start-TestEvaluation $root
        $path = Join-Path (Get-EvaluationDirectory $root $evaluation.evaluationId) 'evaluation.json'
        $persisted = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        Assert-True ($evaluation.evaluationId -match '^[a-f0-9]{32}$') 'Evaluation ID was not returned.'
        Assert-Equal $persisted.evaluationId $evaluation.evaluationId 'Persisted Evaluation ID mismatch.'
        Assert-True ($null -eq $persisted.runId) 'runId must be null before attachment.'
        Assert-Equal $persisted.harness.version '0.1.1' 'Harness version mismatch.'
    }

    Invoke-HarnessTest 'T02 get before workflow is incomplete-safe' {
        $root = New-TestProject 't02-get-before'
        $evaluation = Start-TestEvaluation $root
        $status = & $get -ProjectRoot $root -EvaluationId $evaluation.evaluationId
        Assert-Equal $status.evaluationStatus 'started' 'Evaluation status mismatch.'
        Assert-Equal $status.workflowStatus 'not_started' 'Workflow status mismatch.'
        Assert-Equal $status.guardResult 'not_available' 'Guard result mismatch.'
        $report = Export-AndRead $root $evaluation.evaluationId
        Assert-Equal $report.result 'INCOMPLETE' 'Not-started result mismatch.'
    }

    Invoke-HarnessTest 'T03 attach paused run' {
        $root = New-TestProject 't03-paused'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'paused01' -Status 'paused'
        $attached = Attach-TestRun $root $evaluation.evaluationId 'paused01'
        $status = & $get -ProjectRoot $root -EvaluationId $evaluation.evaluationId
        Assert-Equal $attached.workflowStatus 'paused' 'Attached workflow status mismatch.'
        Assert-Equal $status.workflowStatus 'paused' 'Observed workflow status mismatch.'
    }

    Invoke-HarnessTest 'T04 attach completed run' {
        $root = New-TestProject 't04-completed'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'complete01' -Status 'completed'
        $attached = Attach-TestRun $root $evaluation.evaluationId 'complete01'
        Assert-Equal $attached.runId 'complete01' 'Completed run was not attached.'
    }

    Invoke-HarnessTest 'T05 attach aborted run' {
        $root = New-TestProject 't05-aborted'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'aborted01' -Status 'aborted' -GateChoice reject
        $attached = Attach-TestRun $root $evaluation.evaluationId 'aborted01'
        Assert-Equal $attached.workflowStatus 'aborted' 'Aborted run was not attached.'
    }

    Invoke-HarnessTest 'T06 attach failed run' {
        $root = New-TestProject 't06-failed'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'failed01' -Status 'failed'
        $attached = Attach-TestRun $root $evaluation.evaluationId 'failed01'
        Assert-Equal $attached.workflowStatus 'failed' 'Failed run was not attached.'
    }

    Invoke-HarnessTest 'T07 unknown run is configuration error' {
        $root = New-TestProject 't07-unknown'
        $evaluation = Start-TestEvaluation $root
        Assert-ConfigurationError {
            Attach-TestRun $root $evaluation.evaluationId 'missing01' *> $null
        }
    }

    Invoke-HarnessTest 'T08 workflow mismatch is configuration error' {
        $root = New-TestProject 't08-workflow-mismatch'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'mismatch01' -WorkflowId 'another-workflow'
        Assert-ConfigurationError {
            Attach-TestRun $root $evaluation.evaluationId 'mismatch01' *> $null
        }
        $persisted = Get-Content -LiteralPath (Join-Path (Get-EvaluationDirectory $root $evaluation.evaluationId) 'evaluation.json') -Raw | ConvertFrom-Json
        Assert-True ($null -eq $persisted.runId) 'Mismatched run must not be attached.'
    }

    Invoke-HarnessTest 'T09 paused export is incomplete' {
        $root = New-TestProject 't09-paused-export'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'paused02' -Status 'paused'
        Attach-TestRun $root $evaluation.evaluationId 'paused02' *> $null
        $report = Export-AndRead $root $evaluation.evaluationId
        Assert-Equal $report.result 'INCOMPLETE' 'Paused result mismatch.'
        Assert-Equal $report.workflow.status 'paused' 'Paused workflow status mismatch.'
    }

    Invoke-HarnessTest 'T10 Gate 1 EOF regression remains reportable' {
        $root = New-TestProject 't10-gate-eof-regression'
        $evaluation = Start-TestEvaluation $root
        $evaluationPath = Join-Path (Get-EvaluationDirectory $root $evaluation.evaluationId) 'evaluation.json'
        Assert-True (Test-Path -LiteralPath $evaluationPath) 'Evaluation must exist before workflow state.'
        Write-WorkflowState $root '42e9b056' -Status 'aborted' -IncidentShape
        Attach-TestRun $root $evaluation.evaluationId '42e9b056' *> $null
        $status = & $get -ProjectRoot $root -EvaluationId $evaluation.evaluationId
        $report = Export-AndRead $root $evaluation.evaluationId
        Assert-Equal $status.workflowStatus 'aborted' 'Regression workflow status mismatch.'
        Assert-Equal $report.result 'REJECTED' 'Structured gate rejection must be REJECTED.'
        Assert-True (Test-Path -LiteralPath (Join-Path (Get-EvaluationDirectory $root $evaluation.evaluationId) 'sdd-acceptance.md')) 'Markdown report was not created.'
    }

    Invoke-HarnessTest 'T11 failed workflow export is failed' {
        $root = New-TestProject 't11-failed-export'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'failed02' -Status 'failed'
        Attach-TestRun $root $evaluation.evaluationId 'failed02' *> $null
        $report = Export-AndRead $root $evaluation.evaluationId
        Assert-Equal $report.result 'FAILED' 'Failed workflow result mismatch.'
    }

    Invoke-HarnessTest 'T12 completed without Guard is failed' {
        $root = New-TestProject 't12-no-guard'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'complete02' -Status 'completed'
        Attach-TestRun $root $evaluation.evaluationId 'complete02' *> $null
        $report = Export-AndRead $root $evaluation.evaluationId
        Assert-Equal $report.result 'FAILED' 'Completed-without-Guard result mismatch.'
        Assert-Equal $report.guard.result 'not_available' 'Missing Guard must remain not_available.'
    }

    Invoke-HarnessTest 'T13 completed with Guard FAIL is failed' {
        $root = New-TestProject 't13-guard-fail'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'complete03' -Status 'completed'
        Attach-TestRun $root $evaluation.evaluationId 'complete03' *> $null
        Write-GuardResult $root 'FAIL'
        $report = Export-AndRead $root $evaluation.evaluationId
        Assert-Equal $report.result 'FAILED' 'Guard FAIL result mismatch.'
    }

    Invoke-HarnessTest 'T14 completed with Guard PASS is accepted' {
        $root = New-TestProject 't14-guard-pass'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'complete04' -Status 'completed' -GateChoice approve
        Attach-TestRun $root $evaluation.evaluationId 'complete04' *> $null
        Write-GuardResult $root 'PASS'
        $report = Export-AndRead $root $evaluation.evaluationId
        Assert-Equal $report.result 'ACCEPTED' 'Guard PASS result mismatch.'
    }

    Invoke-HarnessTest 'T15 multiple evaluations do not overwrite' {
        $root = New-TestProject 't15-multiple'
        $first = Start-TestEvaluation $root -ScenarioId 'scenario-one'
        $second = Start-TestEvaluation $root -ScenarioId 'scenario-two'
        Assert-True ($first.evaluationId -ne $second.evaluationId) 'Evaluation IDs must be unique.'
        Export-AndRead $root $first.evaluationId *> $null
        Export-AndRead $root $second.evaluationId *> $null
        $firstPath = Get-EvaluationDirectory $root $first.evaluationId
        $secondPath = Get-EvaluationDirectory $root $second.evaluationId
        $firstMetadata = Get-Content -LiteralPath (Join-Path $firstPath 'evaluation.json') -Raw | ConvertFrom-Json
        $secondMetadata = Get-Content -LiteralPath (Join-Path $secondPath 'evaluation.json') -Raw | ConvertFrom-Json
        Assert-Equal $firstMetadata.scenarioId 'scenario-one' 'First evaluation was overwritten.'
        Assert-Equal $secondMetadata.scenarioId 'scenario-two' 'Second evaluation was overwritten.'
        Assert-True ((Test-Path -LiteralPath (Join-Path $firstPath 'sdd-acceptance.json')) -and (Test-Path -LiteralPath (Join-Path $secondPath 'sdd-acceptance.json'))) 'Per-evaluation reports are missing.'
    }

    Invoke-HarnessTest 'T16 sanitization excludes sensitive inputs' {
        $root = New-TestProject 't16-sanitization'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'sanitize01' -Status 'completed'
        Attach-TestRun $root $evaluation.evaluationId 'sanitize01' *> $null
        Write-GuardResult $root 'PASS'
        New-Item -ItemType Directory -Path (Join-Path $root 'specs/001') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'specs/001/spec.md') -Value @'
## User Story 1 - SecretCustomer
- **FR-001**: token=super-secret-token
C:\Users\PrivateUser\source\repos\SecretProject
https://private.example.invalid/repository
'@ -Encoding utf8NoBOM
        & $export -ProjectRoot $root -EvaluationId $evaluation.evaluationId *> $null
        $evaluationDirectory = Get-EvaluationDirectory $root $evaluation.evaluationId
        $exports = (Get-Content -LiteralPath (Join-Path $evaluationDirectory 'sdd-acceptance.json') -Raw) +
            (Get-Content -LiteralPath (Join-Path $evaluationDirectory 'sdd-acceptance.md') -Raw)
        Assert-True ($exports -notmatch 'SecretCustomer|super-secret-token|PrivateUser|SecretProject|C:\\Users\\|private\.example') 'Sensitive content leaked into reports.'
    }

    Invoke-HarnessTest 'T17 integration mismatch is configuration error' {
        $root = New-TestProject 't17-integration-mismatch'
        $evaluation = Start-TestEvaluation $root -Integration 'codex'
        Write-WorkflowState $root 'copilot01' -Integration 'copilot'
        Assert-ConfigurationError {
            Attach-TestRun $root $evaluation.evaluationId 'copilot01' *> $null
        }
    }

    Invoke-HarnessTest 'T18 aborted without rejection evidence is failed' {
        $root = New-TestProject 't18-unknown-abort'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'aborted02' -Status 'aborted'
        Attach-TestRun $root $evaluation.evaluationId 'aborted02' *> $null
        $report = Export-AndRead $root $evaluation.evaluationId
        Assert-Equal $report.result 'FAILED' 'Unexplained abort must not invent gate rejection.'
    }

    Invoke-HarnessTest 'T19 current pointer selects the active evaluation' {
        $root = New-TestProject 't19-current'
        Start-TestEvaluation $root -ScenarioId 'first-scenario' *> $null
        $current = Start-TestEvaluation $root -ScenarioId 'current-scenario'
        $status = & $get -ProjectRoot $root
        Assert-Equal $status.evaluationId $current.evaluationId 'Current evaluation pointer mismatch.'
        Assert-Equal $status.scenarioId 'current-scenario' 'Current evaluation scenario mismatch.'
    }

    Invoke-HarnessTest 'T20 acceptance JSON validates against schema 1.0' {
        $root = New-TestProject 't20-schema'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'schema01' -Status 'completed'
        Attach-TestRun $root $evaluation.evaluationId 'schema01' *> $null
        Write-GuardResult $root 'PASS'
        Export-AndRead $root $evaluation.evaluationId *> $null
        $reportPath = Join-Path (Get-EvaluationDirectory $root $evaluation.evaluationId) 'sdd-acceptance.json'
        Assert-True (Test-Json -LiteralPath $reportPath -SchemaFile $schema -ErrorAction Stop) 'Acceptance JSON failed schema validation.'
    }

    Invoke-HarnessTest 'T21 manual AI usage remains allowlisted' {
        $root = New-TestProject 't21-ai-usage'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'aiusage01' -Status 'completed'
        Attach-TestRun $root $evaluation.evaluationId 'aiusage01' *> $null
        Write-GuardResult $root 'PASS'
        $usagePath = Join-Path $root 'ai-usage.json'
        Write-Json $usagePath ([ordered]@{ source = 'manual'; totalTokens = 123; note = 'super-secret-token' })
        & $export -ProjectRoot $root -EvaluationId $evaluation.evaluationId -AiUsagePath $usagePath *> $null
        $raw = Get-Content -LiteralPath (Join-Path (Get-EvaluationDirectory $root $evaluation.evaluationId) 'sdd-acceptance.json') -Raw
        $report = $raw | ConvertFrom-Json
        Assert-Equal $report.aiUsage.totalTokens 123 'Allowed AI usage metric mismatch.'
        Assert-True ($raw -notmatch 'super-secret-token') 'Non-allowlisted AI usage field leaked.'
    }

    Invoke-HarnessTest 'T22 workflow-launch parameters are removed' {
        $command = Get-Command $start
        Assert-True (-not $command.Parameters.ContainsKey('StartWorkflow')) 'StartWorkflow must not be public.'
        Assert-True (-not $command.Parameters.ContainsKey('Description')) 'Description must not be public.'
        $source = Get-Content -LiteralPath $start -Raw
        Assert-True ($source -notmatch 'specify\s+workflow\s+(run|resume)') 'Start script must not invoke workflow commands.'
    }

    Invoke-HarnessTest 'T23 running workflow export is incomplete' {
        $root = New-TestProject 't23-running'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'running01' -Status 'running'
        Attach-TestRun $root $evaluation.evaluationId 'running01' *> $null
        $report = Export-AndRead $root $evaluation.evaluationId
        Assert-Equal $report.result 'INCOMPLETE' 'Running workflow result mismatch.'
        Assert-Equal $report.workflow.status 'running' 'Running workflow status mismatch.'
    }

    Invoke-HarnessTest 'T24 completed with Guard ERROR is failed' {
        $root = New-TestProject 't24-guard-error'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'complete05' -Status 'completed'
        Attach-TestRun $root $evaluation.evaluationId 'complete05' *> $null
        Write-GuardResult $root 'ERROR'
        $report = Export-AndRead $root $evaluation.evaluationId
        Assert-Equal $report.result 'FAILED' 'Guard ERROR result mismatch.'
    }

    Invoke-HarnessTest 'T25 conflicting integration metadata is configuration error' {
        $root = New-TestProject 't25-conflicting-integration'
        $evaluation = Start-TestEvaluation $root
        Write-WorkflowState $root 'conflict01' -Integration 'codex'
        $statePath = Join-Path $root '.specify/workflows/runs/conflict01/state.json'
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        $state.step_results.analyze.integration = 'copilot'
        Write-Json $statePath $state
        Assert-ConfigurationError {
            Attach-TestRun $root $evaluation.evaluationId 'conflict01' *> $null
        }
    }

    if ($script:Failed -gt 0) {
        Write-Output "HARNESS TESTS FAILED: passed=$script:Passed failed=$script:Failed total=$($script:Passed + $script:Failed)"
        exit 1
    }
    Write-Output "ALL HARNESS TESTS PASS: passed=$script:Passed failed=0 total=$script:Passed"
    exit 0
}
finally {
    $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
    $resolvedSystemTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $expectedPrefix = $resolvedSystemTemp.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (
        (Test-Path -LiteralPath $resolvedTempRoot) -and
        $resolvedTempRoot.StartsWith($expectedPrefix, [System.StringComparison]::OrdinalIgnoreCase) -and
        ([System.IO.Path]::GetFileName($resolvedTempRoot) -match '^dotnet-sdd-harness-tests-[a-f0-9]{32}$')
    ) {
        Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force
    }
}
