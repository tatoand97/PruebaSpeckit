[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [ValidatePattern('^[a-f0-9]{32}$')][string]$EvaluationId,
    [string]$AiUsagePath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SddHarness.Common.ps1')

$root = Resolve-SddProjectRoot $ProjectRoot
$evaluation = Resolve-Evaluation $root $EvaluationId
$metadata = $evaluation.Metadata
$runId = [string](Get-PropertyValue $metadata 'runId')
$state = if ($runId) { Get-WorkflowState $root $runId } else { $null }
$workflowStatus = if ($state) { [string](Get-PropertyValue $state 'status') } else { 'not_started' }
$log = if ($runId) { @(Get-WorkflowLog $root $runId) } else { @() }

# Guard 1.0 has no workflow-run identifier. Only consume it after the selected
# workflow has completed, when Guard is expected to have run through its hook.
$guard = if ($workflowStatus -eq 'completed') {
    Read-JsonFile (Join-Path $root 'artifacts/sdd-guard/guard-result.json') -Optional
} else {
    $null
}
$documents = Get-DocumentCounters $root

$steps = [System.Collections.Generic.List[object]]::new()
$gateSteps = [System.Collections.Generic.List[object]]::new()
$stateStepResults = Get-PropertyValue $state 'step_results'
if ($stateStepResults) {
    foreach ($property in $stateStepResults.PSObject.Properties) {
        $step = $property.Value
        $stepType = [string](Get-PropertyValue $step 'type')
        $stepStatus = [string](Get-PropertyValue $step 'status')
        $steps.Add([ordered]@{
            id = [string]$property.Name
            type = $stepType
            status = $stepStatus
        })
        if ($stepType -eq 'gate') {
            $gateSteps.Add($step)
        }
    }
}

$gatesApproved = 0
$gatesRejected = 0
foreach ($gate in $gateSteps) {
    $output = Get-PropertyValue $gate 'output'
    $choice = [string](Get-PropertyValue $output 'choice')
    $aborted = Get-PropertyValue $output 'aborted'
    if ($choice -eq 'approve') {
        $gatesApproved++
    }
    if ($choice -eq 'reject' -and $aborted -eq $true) {
        $gatesRejected++
    }
}

$guardResult = if ($guard) { [string](Get-PropertyValue $guard 'result') } else { 'not_available' }
$blockingFrameworkError = $workflowStatus -eq 'failed' -or $guardResult -eq 'ERROR'
$result = if ($workflowStatus -eq 'aborted' -and $gatesRejected -gt 0) {
    'REJECTED'
}
elseif ($workflowStatus -eq 'aborted' -or $workflowStatus -eq 'failed') {
    'FAILED'
}
elseif ($workflowStatus -eq 'completed' -and $guardResult -in @('FAIL', 'ERROR')) {
    'FAILED'
}
elseif ($workflowStatus -eq 'completed' -and -not $guard) {
    'FAILED'
}
elseif ($workflowStatus -eq 'completed' -and $guardResult -eq 'PASS' -and -not $blockingFrameworkError) {
    'ACCEPTED'
}
elseif ($workflowStatus -eq 'completed') {
    'FAILED'
}
else {
    'INCOMPLETE'
}

$analyzeCount = @($steps | Where-Object { $_.id -match '(^|:)analyze($|:)' }).Count
$convergeCount = @($steps | Where-Object { $_.id -match '(^|:)converge($|:)' }).Count
$failedSteps = @($steps | Where-Object status -eq 'failed').Count
$pauses = @($log | Where-Object { $_.event -match 'pause' -or $_.status -eq 'paused' }).Count
$resumes = @($log | Where-Object { $_.event -match 'resume' }).Count

$guardObject = Get-PropertyValue $guard 'guard'
$guardSummarySource = Get-PropertyValue $guard 'summary'
$guardSummary = [ordered]@{
    version = if ($guard) { [string](Get-PropertyValue $guardObject 'version') } else { 'not_available' }
    result = $guardResult
    checksPassed = if ($guard) { [int](Get-PropertyValue $guardSummarySource 'passed') } else { 'not_available' }
    checksFailed = if ($guard) { [int](Get-PropertyValue $guardSummarySource 'failed') } else { 'not_available' }
    advisories = if ($guard) { [int](Get-PropertyValue $guardSummarySource 'advisory') } else { 'not_available' }
    notApplicable = if ($guard) { [int](Get-PropertyValue $guardSummarySource 'notApplicable') } else { 'not_available' }
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
        harness = 'dotnet-sdd-harness@0.1.1'
    }
    environment = [ordered]@{
        os = if ($IsWindows) { 'windows' } elseif ($IsLinux) { 'linux' } else { 'macos' }
        powershell = $PSVersionTable.PSVersion.ToString()
        dotnet = (& dotnet --version 2>$null)
        integration = [string](Get-PropertyValue $metadata 'integration')
    }
    workflow = [ordered]@{
        id = [string](Get-PropertyValue $metadata 'workflowId')
        version = '0.1.0'
        runId = if ($runId) { $runId } else { 'not_available' }
        status = $workflowStatus
        steps = @($steps)
        failedSteps = $failedSteps
        durationSeconds = Get-SafeDurationSeconds $state
    }
    humanInteraction = [ordered]@{
        gatesReached = $gateSteps.Count
        gatesApproved = $gatesApproved
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

$jsonPath = Join-Path $evaluation.Directory 'sdd-acceptance.json'
$mdPath = Join-Path $evaluation.Directory 'sdd-acceptance.md'
Write-JsonFile $jsonPath $report

$md = @(
    '# SDD Acceptance Report'
    ''
    '| Field | Value |'
    '|---|---|'
    "| Evaluation ID | $($evaluation.Id) |"
    "| Final result | $result |"
    "| Scenario | $([string](Get-PropertyValue $metadata 'scenarioId')) |"
    "| Workflow | $([string](Get-PropertyValue $metadata 'workflowId'))@$($report.workflow.version) |"
    "| Workflow Run ID | $(if ($runId) { $runId } else { 'not_available' }) |"
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
