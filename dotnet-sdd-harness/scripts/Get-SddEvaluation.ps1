[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SddHarness.Common.ps1')
$root = [System.IO.Path]::GetFullPath($ProjectRoot)
$metadata = Read-JsonFile (Join-Path (Get-EvaluationRoot $root) 'evaluation.json')
$state = Get-LatestWorkflowState $root $metadata.runId
$guard = Read-JsonFile (Join-Path $root 'artifacts/sdd-guard/guard-result.json') -Optional

[ordered]@{
    scenarioId = $metadata.scenarioId
    workflowId = $metadata.workflowId
    runId = if ($state) { $state.run_id } else { $metadata.runId }
    workflowStatus = if ($state) { $state.status } else { 'not_available' }
    guardResult = if ($guard) { $guard.result } else { 'not_available' }
}
