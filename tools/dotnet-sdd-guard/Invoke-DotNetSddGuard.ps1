[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProjectRoot = (Get-Location).Path,

    [Parameter()]
    [string]$EvidencePath,

    [Parameter()]
    [string]$ContractRoot,

    [Parameter()]
    [switch]$VerboseDiagnostics
)

$ErrorActionPreference = 'Stop'
$script:Checks = [System.Collections.Generic.List[object]]::new()
$script:ConfigurationErrors = [System.Collections.Generic.List[string]]::new()

function Add-Check {
    param(
        [string]$Id,
        [string]$Category,
        [ValidateSet('PASS', 'FAIL', 'ADVISORY', 'NOT_APPLICABLE')]
        [string]$Status,
        [ValidateSet('HARD', 'ADVISORY', 'NONE')]
        [string]$Severity,
        [string]$Message,
        [string]$Evidence
    )

    $script:Checks.Add([ordered]@{
        id       = $Id
        category = $Category
        status   = $Status
        severity = $Severity
        message  = $Message
        evidence = $Evidence
    })
}

function Add-ConfigError {
    param([string]$Message)
    $script:ConfigurationErrors.Add($Message)
}

function Get-SafeFiles {
    param(
        [string]$Root,
        [string[]]$Extensions = @('.cs', '.csproj', '.props', '.targets', '.json', '.yaml', '.yml', '.ps1', '.md')
    )

    Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in $Extensions -and
            $_.FullName -notmatch '[\\/](bin|obj|artifacts|TestResults|\.git)[\\/]'
        }
}

function Get-ImplementationFiles {
    param([string]$Root)

    $extensions = @('.cs', '.csproj', '.props', '.targets')
    $excludedPathPattern = '[\\/](\.github|\.codex|openspec|legacy|docs|tools|artifacts|TestResults|bin|obj|\.git)[\\/]'

    Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in $extensions -and
            $_.FullName -notmatch $excludedPathPattern
        }
}

function Test-AnyPattern {
    param(
        [System.IO.FileInfo[]]$Files,
        [string[]]$Patterns
    )

    foreach ($file in $Files) {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        foreach ($pattern in $Patterns) {
            if ($content -match $pattern) { return $true }
        }
    }
    return $false
}

function Get-ProjectLayer {
    param([System.IO.FileInfo]$Project)
    $name = $Project.BaseName
    foreach ($layer in @('Domain', 'Application', 'Infrastructure', 'Presentation')) {
        if ($name -match "(^|\.)$layer$" -or $Project.FullName -match "[\\/]$layer[\\/]") {
            return $layer
        }
    }
    if ($name -match '\.Server$') { return 'Server' }
    return 'Other'
}

function Get-ProjectModule {
    param([System.IO.FileInfo]$Project)
    if ($Project.FullName -match '[\\/]Modules[\\/]([^\\/]+)[\\/]') { return $Matches[1] }
    if ($Project.BaseName -match '^([^.]+)\.(Domain|Application|Infrastructure|Presentation)$') {
        return $Matches[1]
    }
    return $null
}

function Test-Architecture {
    param([string]$Root)
    $projects = @(Get-ChildItem -LiteralPath $Root -Recurse -Filter '*.csproj' -File |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj|artifacts)[\\/]' })
    $violations = [System.Collections.Generic.List[string]]::new()

    foreach ($project in $projects) {
        $sourceLayer = Get-ProjectLayer $project
        $sourceModule = Get-ProjectModule $project
        $sourceCommon = $project.BaseName -match '^Common\.'
        [xml]$xml = Get-Content -LiteralPath $project.FullName -Raw
        foreach ($reference in @($xml.SelectNodes('//ProjectReference[@Include]'))) {
            $targetPath = [System.IO.Path]::GetFullPath((Join-Path $project.DirectoryName ([string]$reference.GetAttribute('Include'))))
            $target = Get-Item -LiteralPath $targetPath -ErrorAction SilentlyContinue
            if (-not $target) { continue }
            $targetLayer = Get-ProjectLayer $target
            $targetModule = Get-ProjectModule $target
            $targetCommon = $target.BaseName -match '^Common\.'
            $bad = $false

            if ($sourceCommon -and -not $targetCommon) { $bad = $true }
            switch ($sourceLayer) {
                'Domain' {
                    if ($targetLayer -in @('Application', 'Infrastructure', 'Presentation', 'Server')) { $bad = $true }
                    if ($targetCommon -and $targetLayer -ne 'Domain') { $bad = $true }
                    if ($targetLayer -eq 'Domain' -and -not $targetCommon -and $targetModule -and $sourceModule -and $targetModule -ne $sourceModule) { $bad = $true }
                }
                'Application' {
                    if ($targetLayer -in @('Infrastructure', 'Presentation', 'Server')) { $bad = $true }
                    if (-not $targetCommon -and $targetModule -and $sourceModule -and $targetModule -ne $sourceModule) { $bad = $true }
                }
                'Infrastructure' {
                    if ($targetLayer -in @('Presentation', 'Server')) { $bad = $true }
                    if (-not $targetCommon -and $targetModule -and $sourceModule -and $targetModule -ne $sourceModule) { $bad = $true }
                }
                'Presentation' {
                    if ($targetLayer -eq 'Server') { $bad = $true }
                    if ($targetCommon -and $targetLayer -ne 'Presentation') { $bad = $true }
                    if (-not $targetCommon -and $targetModule -and $sourceModule -and $targetModule -ne $sourceModule) { $bad = $true }
                }
                'Server' {
                    if ($targetLayer -ne 'Presentation') { $bad = $true }
                }
            }
            if ($bad) {
                $violations.Add("$($project.BaseName) -> $($target.BaseName)")
            }
        }
    }
    return @($violations)
}

function Invoke-External {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$WorkingDirectory
    )

    $originalLocation = Get-Location
    $pushed = $false
    $combinedOutput = ''
    $exitCode = 0
    try {
        if ($WorkingDirectory) {
            Push-Location -LiteralPath $WorkingDirectory
            $pushed = $true
        }

        $commandName = $FilePath
        if ($FilePath -eq 'dotnet' -and -not [string]::IsNullOrWhiteSpace($env:SDD_GUARD_DOTNET_PATH)) {
            $commandName = $env:SDD_GUARD_DOTNET_PATH
        }

        $resolvedCommand = if (Test-Path -LiteralPath $commandName -PathType Leaf) {
            [System.IO.Path]::GetFullPath($commandName)
        } else {
            (Get-Command -Name $commandName -ErrorAction Stop | Select-Object -First 1).Source
        }
        $captured = if ([System.IO.Path]::GetExtension($resolvedCommand) -ieq '.ps1') {
            & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $resolvedCommand @($Arguments) 2>&1
        } else {
            & $resolvedCommand @($Arguments) 2>&1
        }
        $exitCode = $LASTEXITCODE
        $combinedOutput = ($captured | Out-String).Trim()

        [ordered]@{
            exitCode = $exitCode
            output = $combinedOutput
        }
    }
    finally {
        if ($pushed) {
            Pop-Location
        }
        Set-Location -LiteralPath $originalLocation.Path
    }
}

function Get-ExceptionHandlers {
    param([System.IO.FileInfo[]]$SourceFiles)

    $registrations = [System.Collections.Generic.List[object]]::new()
    $handlerDefinitions = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($file in $SourceFiles) {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $lines = $content -split "`r?`n"
        for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
            $line = $lines[$lineIndex]
            $match = [regex]::Match($line, 'AddExceptionHandler\s*<\s*([^>]+)\s*>')
            if ($match.Success) {
                $handlerType = ($match.Groups[1].Value -replace '\s+', '')
                $registrations.Add([ordered]@{
                        file = $file.FullName
                        line = $lineIndex + 1
                        handler = $handlerType
                    })
            }
        }

        foreach ($classMatch in [regex]::Matches($content, 'class\s+([A-Za-z0-9_]+)\b[^\{]*IExceptionHandler')) {
            $className = $classMatch.Groups[1].Value
            $classStart = $classMatch.Index
            $openingBrace = $content.IndexOf('{', $classStart)
            if ($openingBrace -lt 0) { continue }

            $depth = 0
            $classEnd = -1
            for ($index = $openingBrace; $index -lt $content.Length; $index++) {
                $char = $content[$index]
                if ($char -eq '{') {
                    $depth++
                    continue
                }
                if ($char -eq '}') {
                    $depth--
                    if ($depth -eq 0) {
                        $classEnd = $index
                        break
                    }
                }
            }
            if ($classEnd -lt 0) { continue }

            $classBody = $content.Substring($openingBrace, $classEnd - $openingBrace + 1)
            $handlerDefinitions[$className] = [ordered]@{
                returnTrue  = (
                    ($classBody -match '\breturn\s+true\s*;') -or
                    ($classBody -match '\breturn\s+(?:ValueTask|Task)\.FromResult\s*\(\s*true\s*\)\s*;')
                )
                returnFalse = (
                    ($classBody -match '\breturn\s+false\s*;') -or
                    ($classBody -match '\breturn\s+(?:ValueTask|Task)\.FromResult\s*\(\s*false\s*\)\s*;')
                )
            }
        }
    }

    return [ordered]@{
        registrations = @($registrations | Sort-Object file, line)
        handlerDefinitions = $handlerDefinitions
    }
}

function Test-ExceptionHandlerOrder {
    param([System.IO.FileInfo[]]$SourceFiles)

    $handlers = Get-ExceptionHandlers $SourceFiles
    $registrations = @($handlers.registrations)
    $definitions = $handlers.handlerDefinitions

    if ($registrations.Count -eq 0) {
        return [ordered]@{
            status = 'ADVISORY'
            message = 'Could not verify IExceptionHandler registration order.'
            evidence = 'No AddExceptionHandler<T>() calls were found in implementation files.'
        }
    }

    $registrationFiles = @($registrations.file | Sort-Object -Unique)
    $composed = Test-AnyPattern $SourceFiles @(
        '\bAdd(?!ExceptionHandler\b)[A-Za-z0-9_]*(Presentation|Module|Exception)[A-Za-z0-9_]*\s*\(',
        '\bMap[A-Za-z0-9_]*(Module|Presentation)[A-Za-z0-9_]*\s*\('
    )

    $specific = [System.Collections.Generic.List[object]]::new()
    $fallback = [System.Collections.Generic.List[object]]::new()
    foreach ($registration in $registrations) {
        $typeName = [string]$registration.handler
        $shortName = ($typeName -split '\.')[-1]
        $isFallbackByName = $shortName -match '(Global|Fallback)'
        $definition = if ($definitions.ContainsKey($shortName)) { $definitions[$shortName] } else { $null }
        $isAlwaysTrue = $false
        if ($definition) {
            $isAlwaysTrue = [bool]$definition.returnTrue -and -not [bool]$definition.returnFalse
        }
        if ($isFallbackByName -or $isAlwaysTrue) {
            $fallback.Add($registration)
        }
        else {
            $specific.Add($registration)
        }
    }

    $certainty = ($registrationFiles.Count -eq 1) -and (-not $composed)
    $firstSpecific = if ($specific.Count -gt 0) { $specific[0] } else { $null }
    $firstFallback = if ($fallback.Count -gt 0) { $fallback[0] } else { $null }
    $hasFallbackReturningTrue = @($fallback | Where-Object {
            $typeName = (($_.handler -split '\.')[-1])
            if (-not $definitions.ContainsKey($typeName)) { return $false }
            return [bool]$definitions[$typeName].returnTrue
        }).Count -gt 0

    if ($firstSpecific -and $firstFallback -and $hasFallbackReturningTrue) {
        $specificFirst = $false
        if ($firstSpecific.file -eq $firstFallback.file) {
            $specificFirst = [int]$firstSpecific.line -lt [int]$firstFallback.line
        }

        if ($specificFirst) {
            if ($certainty) {
                return [ordered]@{
                    status = 'PASS'
                    message = 'Specific exception handlers are registered before fallback handlers.'
                    evidence = "specific=$($firstSpecific.handler)@$($firstSpecific.line); fallback=$($firstFallback.handler)@$($firstFallback.line)"
                }
            }
            return [ordered]@{
                status = 'ADVISORY'
                message = 'Specific handlers appear before fallback handlers, but registration flow crosses composition boundaries.'
                evidence = "files=$($registrationFiles.Count); composed=$composed; firstSpecific=$($firstSpecific.handler); firstFallback=$($firstFallback.handler)"
            }
        }

        if ($certainty) {
            return [ordered]@{
                status = 'FAIL'
                message = 'Fallback/global exception handler is registered before a specific handler.'
                evidence = "firstFallback=$($firstFallback.handler)@$($firstFallback.line); firstSpecific=$($firstSpecific.handler)@$($firstSpecific.line); fallbackReturnsTrue=$hasFallbackReturningTrue"
            }
        }

        return [ordered]@{
            status = 'ADVISORY'
            message = 'Fallback/global handler may preempt specific handlers, but composition order could not be proven with certainty.'
            evidence = "files=$($registrationFiles.Count); composed=$composed; fallbackReturnsTrue=$hasFallbackReturningTrue"
        }
    }

    if ($hasFallbackReturningTrue -and $specific.Count -eq 0) {
        return [ordered]@{
            status = 'ADVISORY'
            message = 'A global/fallback handler that returns true was found without detectable specific handler registrations.'
            evidence = "fallbackRegistrations=$($fallback.Count); specificRegistrations=0"
        }
    }

    return [ordered]@{
        status = 'ADVISORY'
        message = 'IExceptionHandler ordering could not be verified deterministically.'
        evidence = "registrations=$($registrations.Count); fallback=$($fallback.Count); specific=$($specific.Count); files=$($registrationFiles.Count)"
    }
}

function Get-Exc001Severity {
    param([string]$Status)

    switch ($Status) {
        'PASS' { return 'HARD' }
        'FAIL' { return 'HARD' }
        'ADVISORY' { return 'ADVISORY' }
        'NOT_APPLICABLE' { return 'NONE' }
        default { return 'ADVISORY' }
    }
}

function New-RunResultsRoot {
    param([string]$Root)

    $rawRoot = Join-Path $Root 'artifacts/sdd-guard/raw'
    New-Item -ItemType Directory -Path $rawRoot -Force | Out-Null
    $runId = Get-Date -Format 'yyyyMMddHHmmssfff'
    $runRoot = Join-Path $rawRoot ("run-" + $runId + "-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
    return $runRoot
}

function Resolve-Solution {
    param([string]$Root)
    $solutions = @(Get-ChildItem -LiteralPath $Root -File | Where-Object { $_.Extension -in @('.sln', '.slnx') })
    if ($solutions.Count -ne 1) {
        Add-ConfigError "Expected exactly one .sln or .slnx at project root; found $($solutions.Count)."
        return $null
    }
    return $solutions[0]
}

function Test-DotNet10 {
    param([string]$Root)
    $global = Join-Path $Root 'global.json'
    if (Test-Path -LiteralPath $global) {
        try {
            $sdkVersion = (Get-Content -LiteralPath $global -Raw | ConvertFrom-Json).sdk.version
            if ($sdkVersion -and $sdkVersion -notmatch '^10\.') { return $false }
        }
        catch { return $false }
    }

    $frameworkValues = [System.Collections.Generic.List[string]]::new()
    $props = Join-Path $Root 'Directory.Build.props'
    if (Test-Path -LiteralPath $props) {
        [xml]$propsXml = Get-Content -LiteralPath $props -Raw
        foreach ($node in @($propsXml.SelectNodes('//TargetFramework | //TargetFrameworks'))) {
            if ($node.InnerText) { $frameworkValues.Add([string]$node.InnerText) }
        }
    }
    foreach ($project in @(Get-ChildItem -LiteralPath $Root -Recurse -Filter '*.csproj' -File |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj|artifacts)[\\/]' })) {
        [xml]$xml = Get-Content -LiteralPath $project.FullName -Raw
        foreach ($node in @($xml.SelectNodes('//TargetFramework | //TargetFrameworks'))) {
            if ($node.InnerText) { $frameworkValues.Add([string]$node.InnerText) }
        }
    }
    return $frameworkValues.Count -gt 0 -and @($frameworkValues | Where-Object { $_ -split ';' | Where-Object { $_ -notmatch '^net10\.0($|-)' } }).Count -eq 0
}

function Get-Coverage {
    param([string]$ResultsRoot)
    $reports = @(Get-ChildItem -LiteralPath $ResultsRoot -Recurse -Filter 'coverage.cobertura.xml' -File -ErrorAction SilentlyContinue)
    $valid = 0
    $covered = 0
    $matched = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($report in $reports) {
        [xml]$xml = Get-Content -LiteralPath $report.FullName -Raw
        foreach ($package in @($xml.coverage.packages.package)) {
            $assembly = [string]$package.name
            if ($assembly -notmatch '\.(Domain|Application)$') { continue }
            [void]$matched.Add($assembly)
            foreach ($line in @($package.classes.class.lines.line)) {
                $valid++
                if ([int]$line.hits -gt 0) { $covered++ }
            }
        }
    }
    if ($matched.Count -eq 0 -or $valid -eq 0) { return $null }
    return [math]::Round(($covered * 100.0) / $valid, 2)
}

function Get-TestCounts {
    param([string]$ResultsRoot)
    $counts = [ordered]@{ executed = 0; passed = 0; failed = 0; skipped = 0 }
    foreach ($trx in @(Get-ChildItem -LiteralPath $ResultsRoot -Recurse -Filter '*.trx' -File -ErrorAction SilentlyContinue)) {
        [xml]$xml = Get-Content -LiteralPath $trx.FullName -Raw
        $c = $xml.TestRun.ResultSummary.Counters
        if ($c) {
            $counts.executed += [int]$c.executed
            $counts.passed += [int]$c.passed
            $counts.failed += [int]$c.failed
            $counts.skipped += [int]$c.notExecuted
        }
    }
    return $counts
}

function Write-GuardReport {
    param([string]$Root)
    $artifactRoot = Join-Path $Root 'artifacts/sdd-guard'
    New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
    $failed = @($script:Checks | Where-Object { $_.severity -eq 'HARD' -and $_.status -eq 'FAIL' }).Count
    $result = if ($script:ConfigurationErrors.Count -gt 0) { 'ERROR' } elseif ($failed -gt 0) { 'FAIL' } else { 'PASS' }
    $report = [ordered]@{
        schemaVersion = '1.0'
        guard = [ordered]@{ id = 'dotnet-sdd-guard'; version = '2.0.0' }
        result = $result
        checks = @($script:Checks)
        configurationErrors = @($script:ConfigurationErrors | ForEach-Object { 'Guard configuration or execution error.' })
        summary = [ordered]@{
            passed = @($script:Checks | Where-Object status -eq 'PASS').Count
            failed = $failed
            advisory = @($script:Checks | Where-Object status -eq 'ADVISORY').Count
            notApplicable = @($script:Checks | Where-Object status -eq 'NOT_APPLICABLE').Count
        }
    }
    $jsonPath = Join-Path $artifactRoot 'guard-result.json'
    $mdPath = Join-Path $artifactRoot 'guard-result.md'
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding utf8NoBOM
    $md = [System.Collections.Generic.List[string]]::new()
    $md.Add('# .NET SDD Guard Result')
    $md.Add('')
    $md.Add("**Result:** $result")
    $md.Add('')
    $md.Add('| Check | Category | Severity | Status | Message | Evidence |')
    $md.Add('|---|---|---|---|---|---|')
    foreach ($check in $script:Checks) {
        $message = ([string]$check.message).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
        $evidence = ([string]$check.evidence).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
        $md.Add("| $($check.id) | $($check.category) | $($check.severity) | $($check.status) | $message | $evidence |")
    }
    if ($script:ConfigurationErrors.Count -gt 0) {
        $md.Add('')
        $md.Add('Configuration or execution errors were detected. Details remain local to avoid disclosing paths.')
    }
    $md | Set-Content -LiteralPath $mdPath -Encoding utf8NoBOM
    return $result
}

$resolvedRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$resolvedContractRoot = if ([string]::IsNullOrWhiteSpace($ContractRoot)) {
    $resolvedRoot
} else {
    [System.IO.Path]::GetFullPath($ContractRoot)
}
$evidence = $null
try {
    if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
        throw 'Project root does not exist.'
    }
    if ($EvidencePath) {
        $evidence = Get-Content -LiteralPath $EvidencePath -Raw | ConvertFrom-Json
    }

    $solution = Resolve-Solution $resolvedRoot
    $files = @(Get-SafeFiles $resolvedRoot)
    $implementationFiles = @(Get-ImplementationFiles $resolvedRoot)
    $projects = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -Filter '*.csproj' -File |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj|artifacts)[\\/]' })
    $http = @($projects | Where-Object { (Get-ProjectLayer $_) -in @('Presentation', 'Server') }).Count -gt 0 -or
        (Test-Path -LiteralPath (Join-Path $resolvedContractRoot 'openspec/specs'))

    if (Test-DotNet10 $resolvedRoot) {
        Add-Check 'SDK001' 'sdk' 'PASS' 'HARD' '.NET 10 target is configured.' 'SDK/framework declarations are consistent.'
    } else {
        Add-Check 'SDK001' 'sdk' 'FAIL' 'HARD' '.NET 10 target is not configured consistently.' 'SDK/framework declarations did not meet the baseline.'
    }

    $architecture = @(Test-Architecture $resolvedRoot)
    if ($architecture.Count -eq 0) {
        Add-Check 'ARCH001' 'architecture' 'PASS' 'HARD' 'Project reference direction is valid.' 'No prohibited ProjectReference edges found.'
    } else {
        Add-Check 'ARCH001' 'architecture' 'FAIL' 'HARD' 'Prohibited project reference direction detected.' "$($architecture.Count) prohibited edge(s) found."
    }

    $nonInfrastructure = @($files | Where-Object {
        $_.Extension -in @('.cs', '.csproj') -and
        $_.FullName -match '[\\/][^\\/]*(Domain|Application|Presentation)[\\/]'
    })
    $persistencePatterns = @(
        '\bDbContext\b', 'Microsoft\.EntityFrameworkCore', 'MongoDB\.Driver',
        'MongoDB\.EntityFrameworkCore', 'Microsoft\.Data\.SqlClient', 'System\.Data\.SqlClient'
    )
    if (Test-AnyPattern $nonInfrastructure $persistencePatterns) {
        Add-Check 'PERSIST001' 'persistence' 'FAIL' 'HARD' 'Concrete persistence leaked outside Infrastructure.' 'A prohibited persistence API/package was detected in a non-Infrastructure layer.'
    } else {
        Add-Check 'PERSIST001' 'persistence' 'PASS' 'HARD' 'Persistence ownership is valid.' 'No prohibited persistence API/package found outside Infrastructure.'
    }

    $migrationDirectory = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -Directory -Filter 'Migrations' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](\.github|\.codex|openspec|legacy|docs|tools|artifacts|TestResults|bin|obj|\.git)[\\/]' }).Count -gt 0
    $migrationFiles = @($implementationFiles | Where-Object { $_.Name -match '(Migration|ModelSnapshot)\.cs$' })
    $migrationPatterns = @(
        '\bdotnet-ef\b', 'Microsoft\.EntityFrameworkCore\.Design', '\bDatabase\.Migrate\s*\(',
        '\bMigrateAsync\s*\(', '\bdotnet\s+ef\s+migrations\b', '\bdotnet\s+ef\s+database\s+update\b',
        '\bEnsureCreated(?:Async)?\s*\('
    )
    if ($migrationDirectory -or $migrationFiles.Count -gt 0 -or (Test-AnyPattern $implementationFiles $migrationPatterns)) {
        Add-Check 'MIG001' 'persistence' 'FAIL' 'HARD' 'EF Core migrations or prohibited database initialization detected.' 'At least one prohibited migration/design-time/initialization marker was found.'
    } else {
        Add-Check 'MIG001' 'persistence' 'PASS' 'HARD' 'No EF Core migrations or substitute initialization detected.' 'Prohibited markers were absent.'
    }

    if ($http) {
        $hasWolverine = Test-AnyPattern $implementationFiles @('WolverineFx')
        $hasMediatorOnly = Test-AnyPattern $implementationFiles @('DurabilityMode\.MediatorOnly')
        Add-Check 'WOLV001' 'messaging' $(if ($hasWolverine) { 'PASS' } else { 'FAIL' }) 'HARD' `
            $(if ($hasWolverine) { 'Wolverine dependency is present.' } else { 'Wolverine dependency is missing for an HTTP application.' }) `
            $(if ($hasWolverine) { 'WolverineFx marker found.' } else { 'No WolverineFx marker found.' })
        Add-Check 'WOLV002' 'messaging' $(if ($hasMediatorOnly) { 'PASS' } else { 'FAIL' }) 'HARD' `
            $(if ($hasMediatorOnly) { 'Wolverine is configured as mediator-only.' } else { 'DurabilityMode.MediatorOnly is missing.' }) `
            $(if ($hasMediatorOnly) { 'MediatorOnly marker found.' } else { 'MediatorOnly marker absent.' })
        $transport = Test-AnyPattern $implementationFiles @('WolverineFx\.(RabbitMQ|AzureServiceBus|Kafka|AmazonSqs|Pulsar|Nats)')
        Add-Check 'WOLV003' 'messaging' $(if ($transport) { 'FAIL' } else { 'PASS' }) 'HARD' `
            $(if ($transport) { 'A distributed Wolverine transport package contradicts the baseline.' } else { 'No distributed Wolverine transport package was detected.' }) `
            $(if ($transport) { 'A prohibited explicit transport marker was found.' } else { 'No explicit prohibited transport marker found.' })

        $azurePatterns = @(
            'Microsoft\.Azure\.AppConfiguration\.AspNetCore', 'Azure\.Identity',
            'AddAzureAppConfiguration\s*\(', 'DefaultAzureCredential\s*\('
        )
        $azureOk = $true
        foreach ($pattern in $azurePatterns) {
            if (-not (Test-AnyPattern $implementationFiles @($pattern))) { $azureOk = $false }
        }
        $hardcodedAzure = Test-AnyPattern $implementationFiles @('new\s+Uri\s*\(\s*"https://[^"]+\.azconfig\.io')
        Add-Check 'AZURE001' 'configuration' $(if ($azureOk -and -not $hardcodedAzure) { 'PASS' } else { 'FAIL' }) 'HARD' `
            $(if ($azureOk -and -not $hardcodedAzure) { 'Azure App Configuration preparation is present.' } else { 'Azure App Configuration preparation is incomplete or hard-coded.' }) `
            'Required package/API markers and external endpoint handling were checked without contacting Azure.'

        $problemOk = (Test-AnyPattern $implementationFiles @('AddProblemDetails\s*\(')) -and (Test-AnyPattern $implementationFiles @('\bIExceptionHandler\b'))
        Add-Check 'HTTP001' 'http' $(if ($problemOk) { 'PASS' } else { 'FAIL' }) 'HARD' `
            $(if ($problemOk) { 'Problem Details infrastructure is present.' } else { 'AddProblemDetails and IExceptionHandler are required.' }) `
            'HTTP error-handling markers were checked.'

        $controller = Test-AnyPattern $implementationFiles @('\bControllerBase\b', '\[ApiController\]')
        $minimal = Test-AnyPattern $implementationFiles @('\bMap(Get|Post|Put|Delete|Patch|Group)\s*\(')
        if ($controller) {
            Add-Check 'HTTP002' 'http' 'ADVISORY' 'ADVISORY' 'Controllers were detected; confirm Minimal APIs remain the primary architecture.' 'Controller architecture markers found.'
        } elseif ($minimal) {
            Add-Check 'HTTP002' 'http' 'PASS' 'HARD' 'Minimal API patterns are present.' 'Minimal API mapping marker found and no controller architecture marker found.'
        } else {
            Add-Check 'HTTP002' 'http' 'ADVISORY' 'ADVISORY' 'Minimal API usage could not be established mechanically.' 'No reliable endpoint mapping marker found.'
        }
    } else {
        foreach ($id in @('WOLV001', 'WOLV002', 'WOLV003', 'AZURE001', 'HTTP001', 'HTTP002')) {
            Add-Check $id 'http' 'NOT_APPLICABLE' 'NONE' 'Check does not apply to a non-HTTP project.' 'No Presentation, Server, or OpenSpec capability surface detected.'
        }
    }

    $repositoryMarker = Test-AnyPattern @($implementationFiles | Where-Object { $_.Extension -eq '.cs' }) @('\bI[A-Za-z0-9]+Repository\b', '\bRepository\b')
    if ($repositoryMarker) {
        Add-Check 'PERSIST002' 'persistence' 'PASS' 'ADVISORY' 'Repository abstraction marker is present.' 'A conventional repository marker was found.'
    } else {
        Add-Check 'PERSIST002' 'persistence' 'ADVISORY' 'ADVISORY' 'No recognizable repository abstraction was found.' 'This heuristic is advisory only.'
    }

    $exceptionCheck = Test-ExceptionHandlerOrder @($implementationFiles | Where-Object { $_.Extension -eq '.cs' })
    $exceptionSeverity = Get-Exc001Severity $exceptionCheck.status
    Add-Check 'EXC001' 'exceptions' $exceptionCheck.status $exceptionSeverity $exceptionCheck.message $exceptionCheck.evidence

    if ($solution) {
        $resultsRoot = New-RunResultsRoot $resolvedRoot
        $testProjectCount = 0
        if ($evidence) {
            $restoreOk = [bool]$evidence.restore
            $buildOk = [bool]$evidence.build
            $testOk = [bool]$evidence.tests.ok
            $testCounts = $evidence.tests.counts
            $coverage = if ($null -ne $evidence.coverage) { [double]$evidence.coverage } else { $null }
        } else {
            $restore = Invoke-External 'dotnet' @('restore', $solution.FullName) $resolvedRoot
            $restoreOk = $restore.exitCode -eq 0
            $build = Invoke-External 'dotnet' @('build', $solution.FullName, '-c', 'Release', '--no-restore', '-warnaserror') $resolvedRoot
            $buildOk = $build.exitCode -eq 0
            $unitTestProjects = @($projects | Where-Object {
                ($_.BaseName -match '(^|\.)UnitTests$' -or $_.FullName -match '[\\/]UnitTests[\\/]') -and
                $_.BaseName -notmatch '(Integration|Performance|E2E|Acceptance)'
            })
            if ($unitTestProjects.Count -eq 0) {
                $unitTestProjects = @($projects | Where-Object {
                    $_.FullName -match '[\\/]tests?[\\/]' -and
                    $_.BaseName -notmatch '(Integration|Performance|E2E|Acceptance)'
                })
            }
            $testProjectCount = $unitTestProjects.Count
            $testOk = $unitTestProjects.Count -gt 0
            if (-not $testOk) {
                Add-ConfigError 'No unambiguous UnitTests project was found.'
            }
            $testIndex = 0
            foreach ($unitProject in $unitTestProjects) {
                $testIndex++
                $test = Invoke-External 'dotnet' @(
                    'test', $unitProject.FullName, '-c', 'Release', '--no-build',
                    '--logger', "trx;LogFilePrefix=sdd-guard-$testIndex", '--results-directory', $resultsRoot,
                    '--collect:XPlat Code Coverage',
                    '--', 'DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=cobertura'
                ) $resolvedRoot
                if ($test.exitCode -ne 0) { $testOk = $false }
            }
            $testCounts = Get-TestCounts $resultsRoot
            $coverage = Get-Coverage $resultsRoot
        }
        Add-Check 'RESTORE001' 'build' $(if ($restoreOk) { 'PASS' } else { 'FAIL' }) 'HARD' `
            $(if ($restoreOk) { 'dotnet restore succeeded.' } else { 'dotnet restore failed.' }) 'Exit code was evaluated; command output is not exported.'
        Add-Check 'BUILD001' 'build' $(if ($buildOk) { 'PASS' } else { 'FAIL' }) 'HARD' `
            $(if ($buildOk) { 'Release build succeeded with warnings treated as errors.' } else { 'Release build failed or produced a .NET warning.' }) 'Build used -warnaserror; output is not exported.'
        Add-Check 'TEST001' 'tests' $(if ($testOk -and [int]$testCounts.failed -eq 0) { 'PASS' } else { 'FAIL' }) 'HARD' `
            $(if ($testOk) { 'Unit test execution succeeded.' } else { 'Unit test execution failed.' }) `
            "projects=$testProjectCount; executed=$($testCounts.executed); passed=$($testCounts.passed); failed=$($testCounts.failed); skipped=$($testCounts.skipped)"
        if ($null -eq $coverage) {
            Add-ConfigError 'Business coverage could not be calculated for Domain/Application assemblies.'
            Add-Check 'COV001' 'coverage' 'FAIL' 'HARD' 'Business line coverage could not be calculated reliably.' 'No usable Domain/Application Cobertura lines were available.'
        } else {
            Add-Check 'COV001' 'coverage' $(if ($coverage -ge 80) { 'PASS' } else { 'FAIL' }) 'HARD' `
                $(if ($coverage -ge 80) { 'Business line coverage meets the 80% threshold.' } else { 'Business line coverage is below 80%.' }) `
                "lineCoveragePercent=$coverage"
        }

        $openApis = @(Get-ChildItem -LiteralPath $resolvedContractRoot -Recurse -Filter 'openapi.yaml' -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -match '[\\/]contracts[\\/]openapi\.yaml$' -and
                $_.FullName -notmatch '[\\/](legacy|bin|obj|artifacts|TestResults|\.git)[\\/]'
            })
        if ($openApis.Count -eq 0) {
            Add-Check 'OPENAPI001' 'openapi' 'NOT_APPLICABLE' 'NONE' 'No applicable OpenAPI contract was found.' 'No active or preserved contracts/openapi.yaml file exists.'
        } else {
            $openApiOk = $true
            if ($evidence -and $null -ne $evidence.openapi) {
                $openApiOk = [bool]$evidence.openapi
            } else {
                foreach ($contract in $openApis) {
                    $lint = Invoke-External 'npx' @('--yes', '@redocly/cli@2.41.1', 'lint', $contract.FullName) $resolvedRoot
                    if ($lint.exitCode -ne 0) { $openApiOk = $false }
                }
            }
            Add-Check 'OPENAPI001' 'openapi' $(if ($openApiOk) { 'PASS' } else { 'FAIL' }) 'HARD' `
                $(if ($openApiOk) { 'Version-pinned Redocly lint succeeded.' } else { 'Version-pinned Redocly lint failed.' }) `
                "$($openApis.Count) contract(s) checked; runtime equivalence was not claimed."
        }
    }
}
catch {
    Add-ConfigError $_.Exception.Message
    if ($VerboseDiagnostics) {
        Write-Warning $_.Exception.Message
        Write-Warning $_.ScriptStackTrace
    }
}

$finalResult = Write-GuardReport $resolvedRoot
Write-Output ".NET SDD Guard: $finalResult"
switch ($finalResult) {
    'PASS' { exit 0 }
    'FAIL' { exit 1 }
    default { exit 2 }
}
