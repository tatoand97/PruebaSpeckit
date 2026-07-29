[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]*$')][string]$WorkflowId,
    [Parameter(Mandatory)][ValidateSet('copilot', 'codex')][string]$Integration,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$ScenarioId,
    [string]$Description,
    [switch]$StartWorkflow
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SddHarness.Common.ps1')
$root = [System.IO.Path]::GetFullPath($ProjectRoot)
if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'ProjectRoot does not exist.' }
$evaluationRoot = Get-EvaluationRoot $root
New-Item -ItemType Directory -Path $evaluationRoot -Force | Out-Null
$runId = $null

if ($StartWorkflow) {
    if (-not $Description) { throw 'Description is required when StartWorkflow is used.' }
    $previous = (Get-Location).Path
    try {
        Set-Location $root
        $output = & specify workflow run $WorkflowId -i "spec=$Description" -i "integration=$Integration" --json
        $code = $LASTEXITCODE
    }
    finally {
        Set-Location $previous
    }
    if ($code -notin @(0, 2)) { throw "Workflow invocation failed." }
    try { $runId = ($output -join "`n" | ConvertFrom-Json).run_id } catch { }
    if (-not $runId) {
        $latest = Get-LatestWorkflowState $root
        if ($latest) { $runId = $latest.run_id }
    }
}

$metadata = [ordered]@{
    schemaVersion = '1.0'
    harness = [ordered]@{ id = 'dotnet-sdd-harness'; version = '0.1.0' }
    scenarioId = $ScenarioId
    workflowId = $WorkflowId
    integration = $Integration
    runId = $runId
    status = 'started'
    startedAt = [DateTimeOffset]::UtcNow.ToString('o')
}
$metadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evaluationRoot 'evaluation.json') -Encoding utf8NoBOM
$metadata
