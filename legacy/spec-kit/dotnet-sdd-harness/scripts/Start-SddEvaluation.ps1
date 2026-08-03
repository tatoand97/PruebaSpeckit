[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]*$')][string]$WorkflowId,
    [Parameter(Mandatory)][ValidateSet('copilot', 'codex')][string]$Integration,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$ScenarioId
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SddHarness.Common.ps1')

$root = Resolve-SddProjectRoot $ProjectRoot
$evaluationId = [guid]::NewGuid().ToString('N')
$evaluationRoot = Get-EvaluationRoot $root
$evaluationDirectory = Get-EvaluationDirectory $root $evaluationId
$metadata = [ordered]@{
    schemaVersion = '1.1'
    evaluationId = $evaluationId
    harness = [ordered]@{ id = 'dotnet-sdd-harness'; version = '0.1.1' }
    scenarioId = $ScenarioId
    workflowId = $WorkflowId
    integration = $Integration
    runId = $null
    status = 'started'
    startedAt = [DateTimeOffset]::UtcNow.ToString('o')
}

Write-JsonFile (Join-Path $evaluationDirectory 'evaluation.json') $metadata
Write-JsonFile (Join-Path $evaluationRoot 'current.json') ([ordered]@{ evaluationId = $evaluationId })
$metadata
