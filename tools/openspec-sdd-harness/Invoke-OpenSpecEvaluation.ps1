[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProjectRoot = (Get-Location).Path,

    [Parameter()]
    [string]$EvaluationId = ("eval-" + (Get-Date -Format 'yyyyMMddHHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)),

    [Parameter()]
    [string]$OpenSpecCommand = 'openspec',

    [Parameter()]
    [string]$GuardScript
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath($ProjectRoot)
if (-not (Test-Path -LiteralPath (Join-Path $root 'openspec/config.yaml') -PathType Leaf)) {
    throw 'The evaluation target is not an initialized OpenSpec project.'
}
if ([string]::IsNullOrWhiteSpace($GuardScript)) {
    $GuardScript = Join-Path $root 'scripts/Invoke-OpenSpecSddGuard.ps1'
}
$resolvedGuard = [IO.Path]::GetFullPath($GuardScript)
if (-not (Test-Path -LiteralPath $resolvedGuard -PathType Leaf)) {
    throw 'The explicit verification guard is missing.'
}
if ($EvaluationId -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]{0,79}$') {
    throw 'EvaluationId must be a safe identifier of at most 80 characters.'
}

$evaluationRoot = Join-Path $root "artifacts/sdd-evaluation/$EvaluationId"
if (Test-Path -LiteralPath $evaluationRoot) {
    throw "Evaluation '$EvaluationId' already exists."
}
New-Item -ItemType Directory -Path $evaluationRoot -Force | Out-Null

$started = [DateTimeOffset]::UtcNow
$original = Get-Location
try {
    Push-Location -LiteralPath $root
    & $OpenSpecCommand validate --all --strict *> $null
    $openSpecExit = $LASTEXITCODE
    & $resolvedGuard -RepositoryRoot $root *> $null
    $guardExit = $LASTEXITCODE
} finally {
    Pop-Location
}

$guardResultPath = Join-Path $root 'PoCFinal/artifacts/sdd-guard/guard-result.json'
$guardResult = if (Test-Path -LiteralPath $guardResultPath -PathType Leaf) {
    (Get-Content -LiteralPath $guardResultPath -Raw | ConvertFrom-Json).result
} else {
    'MISSING'
}
$result = if ($openSpecExit -eq 0 -and $guardExit -eq 0 -and $guardResult -eq 'PASS') { 'accepted' } else { 'failed' }
$finished = [DateTimeOffset]::UtcNow

$record = [ordered]@{
    schemaVersion = '1.0'
    evaluationId = $EvaluationId
    result = $result
    startedAtUtc = $started.ToString('O')
    finishedAtUtc = $finished.ToString('O')
    checks = [ordered]@{
        openSpec = [ordered]@{ exitCode = $openSpecExit; passed = ($openSpecExit -eq 0) }
        guard = [ordered]@{ exitCode = $guardExit; result = $guardResult; passed = ($guardExit -eq 0 -and $guardResult -eq 'PASS') }
    }
    evidence = [ordered]@{
        guardJson = 'PoCFinal/artifacts/sdd-guard/guard-result.json'
        guardMarkdown = 'PoCFinal/artifacts/sdd-guard/guard-result.md'
    }
}
$recordPath = Join-Path $evaluationRoot 'evaluation.json'
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $recordPath -Encoding utf8NoBOM
Write-Output $recordPath.Substring($root.Length + 1)
if ($result -eq 'accepted') { exit 0 }
exit 1
