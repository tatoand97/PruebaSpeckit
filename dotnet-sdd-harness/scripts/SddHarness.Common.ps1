Set-StrictMode -Version Latest

function Get-EvaluationRoot {
    param([string]$ProjectRoot)
    Join-Path ([System.IO.Path]::GetFullPath($ProjectRoot)) 'artifacts/sdd-evaluation'
}

function Read-JsonFile {
    param([string]$Path, [switch]$Optional)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        if ($Optional) { return $null }
        throw "Required JSON file was not found."
    }
    try {
        Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    }
    catch {
        throw "JSON input is invalid."
    }
}

function Get-LatestWorkflowState {
    param([string]$ProjectRoot, [string]$RunId)
    $runs = Join-Path $ProjectRoot '.specify/workflows/runs'
    if ($RunId) {
        if ($RunId -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') { throw 'Invalid workflow run id.' }
        return Read-JsonFile (Join-Path $runs "$RunId/state.json") -Optional
    }
    $states = @(Get-ChildItem -LiteralPath $runs -Recurse -Filter 'state.json' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending)
    if ($states.Count -eq 0) { return $null }
    return Read-JsonFile $states[0].FullName
}

function Get-WorkflowLog {
    param([string]$ProjectRoot, [string]$RunId)
    if (-not $RunId -or $RunId -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') { return @() }
    $path = Join-Path $ProjectRoot ".specify/workflows/runs/$RunId/log.jsonl"
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($line in Get-Content -LiteralPath $path) {
        try { $entries.Add(($line | ConvertFrom-Json)) } catch { }
    }
    return @($entries)
}

function Get-CountOrUnavailable {
    param([object]$Value)
    if ($null -eq $Value) { return 'not_available' }
    return [int]$Value
}

function Get-DocumentCounters {
    param([string]$ProjectRoot)
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
    param([object]$Guard, [string]$Id, [string]$EvidenceKey)
    if (-not $Guard) { return 'not_available' }
    $check = @($Guard.checks | Where-Object id -eq $Id | Select-Object -First 1)
    if ($check.Count -eq 0) { return 'not_available' }
    if ($EvidenceKey -and ([string]$check[0].evidence -match "(?:^|;\s*)$EvidenceKey=([0-9.]+)")) {
        return [double]$Matches[1]
    }
    return [string]$check[0].status
}

function Get-AiUsage {
    param([string]$Path)
    if (-not $Path) { return [ordered]@{ status = 'not_available' } }
    $raw = Read-JsonFile $Path
    if ($raw.source -notin @('manual', 'external')) { throw "ai-usage source must be manual or external." }
    $usage = [ordered]@{ status = 'provided'; source = [string]$raw.source }
    foreach ($field in @('inputTokens', 'outputTokens', 'totalTokens', 'premiumRequests', 'cost')) {
        $property = $raw.PSObject.Properties[$field]
        if ($property -and $null -ne $property.Value -and $property.Value -is [ValueType]) {
            $usage[$field] = $property.Value
        }
    }
    $currency = $raw.PSObject.Properties['currency']
    if ($currency -and $currency.Value -and [string]$currency.Value -match '^[A-Z]{3}$') {
        $usage.currency = [string]$currency.Value
    }
    return $usage
}

function Get-SafeDurationSeconds {
    param([object]$State)
    if (-not $State -or -not $State.created_at -or -not $State.updated_at -or $State.status -ne 'completed') {
        return 'not_available'
    }
    try {
        $start = [DateTimeOffset]::Parse([string]$State.created_at)
        $end = [DateTimeOffset]::Parse([string]$State.updated_at)
        if ($end -lt $start) { return 'not_available' }
        return [math]::Round(($end - $start).TotalSeconds, 3)
    } catch { return 'not_available' }
}
