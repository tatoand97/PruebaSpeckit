[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{32}$')][string]$EvaluationId,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]*$')][string]$RunId
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SddHarness.Common.ps1')

$root = Resolve-SddProjectRoot $ProjectRoot
$evaluation = Resolve-Evaluation $root $EvaluationId
$metadata = $evaluation.Metadata
$state = Get-WorkflowState $root $RunId

$stateRunId = [string](Get-PropertyValue $state 'run_id')
if ($stateRunId -ne $RunId) {
    throw "CONFIGURATION ERROR: Workflow state run id does not match '$RunId'."
}

$expectedWorkflowId = [string](Get-PropertyValue $metadata 'workflowId')
$actualWorkflowId = [string](Get-PropertyValue $state 'workflow_id')
if ($actualWorkflowId -ne $expectedWorkflowId) {
    throw "CONFIGURATION ERROR: Workflow '$actualWorkflowId' does not match evaluation workflow '$expectedWorkflowId'."
}

$stateIntegrations = @(Get-WorkflowIntegrations $state)
$expectedIntegration = [string](Get-PropertyValue $metadata 'integration')
if ($stateIntegrations.Count -gt 1) {
    throw 'CONFIGURATION ERROR: Workflow state contains conflicting integration metadata.'
}
$actualIntegration = if ($stateIntegrations.Count -eq 1) { [string]$stateIntegrations[0] } else { $null }
if ($actualIntegration -and $actualIntegration -ne $expectedIntegration) {
    throw "CONFIGURATION ERROR: Integration '$actualIntegration' does not match evaluation integration '$expectedIntegration'."
}

$existingRunId = [string](Get-PropertyValue $metadata 'runId')
if ($existingRunId -and $existingRunId -ne $RunId) {
    throw "CONFIGURATION ERROR: Evaluation is already attached to workflow run '$existingRunId'."
}

if (-not $existingRunId) {
    $metadata.runId = $RunId
    $metadata | Add-Member -NotePropertyName attachedAt -NotePropertyValue ([DateTimeOffset]::UtcNow.ToString('o'))
    Write-JsonFile (Join-Path $evaluation.Directory 'evaluation.json') $metadata
}

[ordered]@{
    evaluationId = $EvaluationId
    runId = $RunId
    workflowId = $actualWorkflowId
    integration = if ($actualIntegration) { $actualIntegration } else { 'not_available' }
    workflowStatus = [string](Get-PropertyValue $state 'status')
}
