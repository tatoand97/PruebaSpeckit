[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [string]$AiUsagePath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SddHarness.Common.ps1')
$root = [System.IO.Path]::GetFullPath($ProjectRoot)
$evaluationRoot = Get-EvaluationRoot $root
$metadata = Read-JsonFile (Join-Path $evaluationRoot 'evaluation.json')
$state = Get-LatestWorkflowState $root $metadata.runId
$runId = if ($state) { [string]$state.run_id } else { [string]$metadata.runId }
$log = @(Get-WorkflowLog $root $runId)
$guard = Read-JsonFile (Join-Path $root 'artifacts/sdd-guard/guard-result.json') -Optional
$documents = Get-DocumentCounters $root

$steps = [System.Collections.Generic.List[object]]::new()
if ($state -and $state.step_results) {
    foreach ($property in $state.step_results.PSObject.Properties) {
        $steps.Add([ordered]@{
            id = [string]$property.Name
            type = [string]$property.Value.type
            status = [string]$property.Value.status
        })
    }
}
$gateSteps = @($steps | Where-Object type -eq 'gate')
$gatesRejected = @($gateSteps | Where-Object status -eq 'failed').Count
$workflowStatus = if ($state) { [string]$state.status } else { 'not_available' }
$blockingError = $workflowStatus -eq 'failed'

$result = if ($workflowStatus -eq 'aborted' -or $gatesRejected -gt 0) {
    'REJECTED'
} elseif ($workflowStatus -eq 'failed' -or ($guard -and $guard.result -in @('FAIL', 'ERROR'))) {
    'FAILED'
} elseif ($workflowStatus -eq 'completed' -and -not $guard) {
    'FAILED'
} elseif ($workflowStatus -eq 'completed' -and $guard.result -eq 'PASS' -and -not $blockingError) {
    'ACCEPTED'
} else {
    'INCOMPLETE'
}

$analyzeCount = @($steps | Where-Object { $_.id -match '(^|:)analyze($|:)' }).Count
$convergeCount = @($steps | Where-Object { $_.id -match '(^|:)converge($|:)' }).Count
$failedSteps = @($steps | Where-Object status -eq 'failed').Count
$pauses = @($log | Where-Object { $_.event -match 'pause' -or $_.status -eq 'paused' }).Count
$resumes = @($log | Where-Object { $_.event -match 'resume' }).Count

$guardSummary = [ordered]@{
    version = if ($guard) { [string]$guard.guard.version } else { 'not_available' }
    result = if ($guard) { [string]$guard.result } else { 'not_available' }
    checksPassed = if ($guard) { [int]$guard.summary.passed } else { 'not_available' }
    checksFailed = if ($guard) { [int]$guard.summary.failed } else { 'not_available' }
    advisories = if ($guard) { [int]$guard.summary.advisory } else { 'not_available' }
    notApplicable = if ($guard) { [int]$guard.summary.notApplicable } else { 'not_available' }
    coveragePercent = Get-CheckMetric $guard 'COV001' 'lineCoveragePercent'
    testsExecuted = Get-CheckMetric $guard 'TEST001' 'executed'
    testsPassed = Get-CheckMetric $guard 'TEST001' 'passed'
    testsFailed = Get-CheckMetric $guard 'TEST001' 'failed'
    testsSkipped = Get-CheckMetric $guard 'TEST001' 'skipped'
    build = Get-CheckMetric $guard 'BUILD001'
    warningCount = if ($guard -and (Get-CheckMetric $guard 'BUILD001') -eq 'PASS') { 0 } else { 'not_available' }
    openApi = Get-CheckMetric $guard 'OPENAPI001'
    architecture = Get-CheckMetric $guard 'ARCH001'
}

$report = [ordered]@{
    schemaVersion = '1.0'
    framework = [ordered]@{
        preset = 'dotnet-sdd@1.0.1'
        workflow = 'dotnet-sdd-feature@0.1.0'
        guard = 'dotnet-sdd-guard@1.0.0'
        bundle = 'dotnet-sdd@1.0.0'
        harness = 'dotnet-sdd-harness@0.1.0'
    }
    environment = [ordered]@{
        os = if ($IsWindows) { 'windows' } elseif ($IsLinux) { 'linux' } else { 'macos' }
        powershell = $PSVersionTable.PSVersion.ToString()
        dotnet = (& dotnet --version 2>$null)
        integration = [string]$metadata.integration
    }
    workflow = [ordered]@{
        id = [string]$metadata.workflowId
        version = '0.1.0'
        runId = if ($runId) { $runId } else { 'not_available' }
        status = $workflowStatus
        steps = @($steps)
        failedSteps = $failedSteps
        durationSeconds = Get-SafeDurationSeconds $state
    }
    humanInteraction = [ordered]@{
        gatesReached = $gateSteps.Count
        gatesApproved = @($gateSteps | Where-Object status -eq 'completed').Count
        gatesRejected = $gatesRejected
        pauses = $pauses
        resumes = $resumes
    }
    sdd = [ordered]@{
        functionalRequirements = $documents.functionalRequirements
        nonFunctionalRequirements = $documents.nonFunctionalRequirements
        userStories = $documents.userStories
        tasks = $documents.tasks
        completedTasks = $documents.completedTasks
        analyzeExecutions = $analyzeCount
        convergeExecutions = $convergeCount
        tasksAddedByConverge = 'not_available'
    }
    guard = $guardSummary
    aiUsage = Get-AiUsage $AiUsagePath
    result = $result
}

$jsonPath = Join-Path $evaluationRoot 'sdd-acceptance.json'
$mdPath = Join-Path $evaluationRoot 'sdd-acceptance.md'
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding utf8NoBOM

$md = @(
    '# SDD Acceptance Report'
    ''
    "| Field | Value |"
    "|---|---|"
    "| Final result | $result |"
    "| Scenario | $($metadata.scenarioId) |"
    "| Workflow | $($metadata.workflowId)@$($report.workflow.version) |"
    "| Workflow status | $workflowStatus |"
    "| Gates reached / approved / rejected | $($report.humanInteraction.gatesReached) / $($report.humanInteraction.gatesApproved) / $($report.humanInteraction.gatesRejected) |"
    "| Guard | $($guardSummary.result) |"
    "| Guard checks passed / failed | $($guardSummary.checksPassed) / $($guardSummary.checksFailed) |"
    "| AI usage | $($report.aiUsage.status) |"
    ''
    'This report contains counters and status metadata only. Source, business text, payloads, secrets, private URLs, usernames, and absolute project paths are excluded.'
)
$md | Set-Content -LiteralPath $mdPath -Encoding utf8NoBOM
$report
