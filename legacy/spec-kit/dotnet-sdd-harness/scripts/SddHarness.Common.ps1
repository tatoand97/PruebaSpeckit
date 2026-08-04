Set-StrictMode -Version Latest

function Resolve-SddProjectRoot {
    param([Parameter(Mandatory)][string]$ProjectRoot)

    $root = [System.IO.Path]::GetFullPath($ProjectRoot)
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw 'ProjectRoot does not exist.'
    }
    return $root
}

function Get-EvaluationRoot {
    param([Parameter(Mandatory)][string]$ProjectRoot)

    Join-Path ([System.IO.Path]::GetFullPath($ProjectRoot)) 'artifacts/sdd-evaluation'
}

function Assert-EvaluationId {
    param([Parameter(Mandatory)][string]$EvaluationId)

    if ($EvaluationId -notmatch '^[a-f0-9]{32}$') {
        throw 'Invalid evaluation id.'
    }
}

function Get-EvaluationDirectory {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$EvaluationId
    )

    Assert-EvaluationId $EvaluationId
    Join-Path (Get-EvaluationRoot $ProjectRoot) $EvaluationId
}

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path, [switch]$Optional)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        if ($Optional) { return $null }
        throw 'Required JSON file was not found.'
    }
    try {
        Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    }
    catch {
        throw 'JSON input is invalid.'
    }
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value
    )

    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $temporaryPath = Join-Path $directory ('.' + [System.IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $Value | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $temporaryPath -Encoding utf8NoBOM
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Get-PropertyValue {
    param([object]$InputObject, [Parameter(Mandatory)][string]$Name)

    if ($null -eq $InputObject) { return $null }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $null
}

function Resolve-Evaluation {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [string]$EvaluationId
    )

    $evaluationRoot = Get-EvaluationRoot $ProjectRoot
    if (-not $EvaluationId) {
        $current = Read-JsonFile (Join-Path $evaluationRoot 'current.json')
        $EvaluationId = [string](Get-PropertyValue $current 'evaluationId')
        if (-not $EvaluationId) {
            throw 'Current evaluation pointer is invalid.'
        }
    }

    Assert-EvaluationId $EvaluationId
    $directory = Get-EvaluationDirectory $ProjectRoot $EvaluationId
    $metadata = Read-JsonFile (Join-Path $directory 'evaluation.json')
    if ([string](Get-PropertyValue $metadata 'evaluationId') -ne $EvaluationId) {
        throw 'Evaluation metadata does not match the requested evaluation id.'
    }

    [pscustomobject]@{
        Id = $EvaluationId
        Directory = $directory
        Metadata = $metadata
    }
}

function Get-WorkflowState {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [string]$RunId,
        [switch]$Optional
    )

    if (-not $RunId) {
        if ($Optional) { return $null }
        throw 'CONFIGURATION ERROR: Workflow run id is missing.'
    }
    if ($RunId -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') {
        throw 'CONFIGURATION ERROR: Invalid workflow run id.'
    }

    $path = Join-Path $ProjectRoot ".specify/workflows/runs/$RunId/state.json"
    try {
        $state = Read-JsonFile $path -Optional
    }
    catch {
        throw "CONFIGURATION ERROR: Workflow run '$RunId' has invalid state JSON."
    }
    if (-not $state -and -not $Optional) {
        throw "CONFIGURATION ERROR: Workflow run '$RunId' was not found."
    }
    return $state
}

function Get-WorkflowIntegrations {
    param([object]$State)

    $integrations = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $stepResults = Get-PropertyValue $State 'step_results'
    if ($stepResults) {
        foreach ($property in $stepResults.PSObject.Properties) {
            $step = $property.Value
            $integration = [string](Get-PropertyValue $step 'integration')
            if ($integration) { [void]$integrations.Add($integration) }

            $output = Get-PropertyValue $step 'output'
            $outputIntegration = [string](Get-PropertyValue $output 'integration')
            if ($outputIntegration) { [void]$integrations.Add($outputIntegration) }
        }
    }

    return @($integrations | Sort-Object)
}

function Get-WorkflowLog {
    param([Parameter(Mandatory)][string]$ProjectRoot, [string]$RunId)

    if (-not $RunId -or $RunId -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') { return @() }
    $path = Join-Path $ProjectRoot ".specify/workflows/runs/$RunId/log.jsonl"
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($line in Get-Content -LiteralPath $path) {
        try { $entries.Add(($line | ConvertFrom-Json)) } catch { }
    }
    return @($entries)
}

function Get-DocumentCounters {
    param([Parameter(Mandatory)][string]$ProjectRoot)

    $result = [ordered]@{
        functionalRequirements = 'not_available'
        nonFunctionalRequirements = 'not_available'
        userStories = 'not_available'
        tasks = 'not_available'
        completedTasks = 'not_available'
    }
    $specsRoot = Join-Path $ProjectRoot 'specs'
    if (-not (Test-Path -LiteralPath $specsRoot)) { return $result }

    $specFiles = @(Get-ChildItem -LiteralPath $specsRoot -Recurse -Filter 'spec.md' -File -ErrorAction SilentlyContinue)
    if ($specFiles.Count -gt 0) {
        $fr = 0; $nfr = 0; $stories = 0
        foreach ($file in $specFiles) {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            $fr += [regex]::Matches($content, '(?mi)^\s*[-*]\s+\*\*FR-\d+').Count
            $nfr += [regex]::Matches($content, '(?mi)^\s*[-*]\s+\*\*NFR-\d+').Count
            $stories += [regex]::Matches($content, '(?mi)^#{2,4}\s+User Story\b').Count
        }
        $result.functionalRequirements = $fr
        $result.nonFunctionalRequirements = $nfr
        $result.userStories = $stories
    }

    $taskFiles = @(Get-ChildItem -LiteralPath $specsRoot -Recurse -Filter 'tasks.md' -File -ErrorAction SilentlyContinue)
    if ($taskFiles.Count -gt 0) {
        $tasks = 0; $completed = 0
        foreach ($file in $taskFiles) {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            $tasks += [regex]::Matches($content, '(?mi)^\s*-\s+\[[ xX]\]\s+T\d+').Count
            $completed += [regex]::Matches($content, '(?mi)^\s*-\s+\[[xX]\]\s+T\d+').Count
        }
        $result.tasks = $tasks
        $result.completedTasks = $completed
    }
    return $result
}

function Get-CheckMetric {
    param([object]$Guard, [Parameter(Mandatory)][string]$Id, [string]$EvidenceKey)

    if (-not $Guard) { return 'not_available' }
    $checks = Get-PropertyValue $Guard 'checks'
    $check = @($checks | Where-Object id -eq $Id | Select-Object -First 1)
    if ($check.Count -eq 0) { return 'not_available' }
    if ($EvidenceKey -and ([string](Get-PropertyValue $check[0] 'evidence') -match "(?:^|;\s*)$EvidenceKey=([0-9.]+)")) {
        return [double]$Matches[1]
    }
    return [string](Get-PropertyValue $check[0] 'status')
}

function Get-AiUsage {
    param([string]$Path)

    if (-not $Path) { return [ordered]@{ status = 'not_available' } }
    $raw = Read-JsonFile $Path
    if ((Get-PropertyValue $raw 'source') -notin @('manual', 'external')) {
        throw 'ai-usage source must be manual or external.'
    }
    $usage = [ordered]@{ status = 'provided'; source = [string](Get-PropertyValue $raw 'source') }
    foreach ($field in @('inputTokens', 'outputTokens', 'totalTokens', 'premiumRequests', 'cost')) {
        $value = Get-PropertyValue $raw $field
        if ($null -ne $value -and $value -is [ValueType]) {
            $usage[$field] = $value
        }
    }
    $currency = Get-PropertyValue $raw 'currency'
    if ($currency -and [string]$currency -match '^[A-Z]{3}$') {
        $usage.currency = [string]$currency
    }
    return $usage
}

function Get-SafeDurationSeconds {
    param([object]$State)

    $createdAt = Get-PropertyValue $State 'created_at'
    $updatedAt = Get-PropertyValue $State 'updated_at'
    $status = [string](Get-PropertyValue $State 'status')
    if (-not $State -or -not $createdAt -or -not $updatedAt -or $status -ne 'completed') {
        return 'not_available'
    }
    try {
        $start = [DateTimeOffset]::Parse([string]$createdAt)
        $end = [DateTimeOffset]::Parse([string]$updatedAt)
        if ($end -lt $start) { return 'not_available' }
        return [math]::Round(($end - $start).TotalSeconds, 3)
    }
    catch {
        return 'not_available'
    }
}
