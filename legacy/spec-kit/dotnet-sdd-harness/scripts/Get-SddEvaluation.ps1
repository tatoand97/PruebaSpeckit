[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [ValidatePattern('^[a-f0-9]{32}$')][string]$EvaluationId
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SddHarness.Common.ps1')

$root = Resolve-SddProjectRoot $ProjectRoot
$evaluation = Resolve-Evaluation $root $EvaluationId
$metadata = $evaluation.Metadata
$runId = [string](Get-PropertyValue $metadata 'runId')
$state = if ($runId) { Get-WorkflowState $root $runId } else { $null }
$workflowStatus = if ($state) { [string](Get-PropertyValue $state 'status') } else { 'not_started' }
$guard = if ($workflowStatus -eq 'completed') {
    Read-JsonFile (Join-Path $root 'artifacts/sdd-guard/guard-result.json') -Optional
} else {
    $null
}

[ordered]@{
    evaluationId = $evaluation.Id
    evaluationStatus = [string](Get-PropertyValue $metadata 'status')
    scenarioId = [string](Get-PropertyValue $metadata 'scenarioId')
    workflowId = [string](Get-PropertyValue $metadata 'workflowId')
    runId = if ($runId) { $runId } else { $null }
    workflowStatus = $workflowStatus
    guardResult = if ($guard) { [string](Get-PropertyValue $guard 'result') } else { 'not_available' }
}
