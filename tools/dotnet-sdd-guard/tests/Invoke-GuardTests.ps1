[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$guard = (Resolve-Path (Join-Path $PSScriptRoot '../Invoke-DotNetSddGuard.ps1')).Path
$repositoryGuard = (Resolve-Path (Join-Path $PSScriptRoot '../../../scripts/Invoke-OpenSpecSddGuard.ps1')).Path
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("dotnet-sdd-guard-tests-" + [guid]::NewGuid().ToString('N'))
$script:Passed = 0
$script:Failed = 0

function Write-Utf8 {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8NoBOM
}

function New-EvidenceFile {
    param([string]$Root)

    $evidence = [ordered]@{
        restore = $true
        build = $true
        tests = [ordered]@{
            ok = $true
            counts = [ordered]@{
                executed = 11
                passed = 11
                failed = 0
                skipped = 0
            }
        }
        coverage = 85
        openapi = $true
    }

    $path = Join-Path $Root 'evidence.json'
    $evidence | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding utf8NoBOM
    return $path
}

function New-Fixture {
    param(
        [string]$Name,
        [switch]$NoSpecs
    )

    $root = Join-Path $tempRoot $Name
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    Write-Utf8 (Join-Path $root 'Fixture.slnx') '<Solution />'
    Write-Utf8 (Join-Path $root 'global.json') '{"sdk":{"version":"10.0.100"}}'
    Write-Utf8 (Join-Path $root 'Directory.Build.props') '<Project><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>'

    Write-Utf8 (Join-Path $root 'src/Modules/Sales/Sales.Domain/Sales.Domain.csproj') '<Project Sdk="Microsoft.NET.Sdk" />'
    Write-Utf8 (Join-Path $root 'src/Modules/Sales/Sales.Domain/Order.cs') 'namespace Sales.Domain; public sealed class Order {}'

    Write-Utf8 (Join-Path $root 'src/Modules/Sales/Sales.Application/Sales.Application.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../Sales.Domain/Sales.Domain.csproj" /></ItemGroup><ItemGroup><PackageReference Include="WolverineFx" /></ItemGroup></Project>'
    Write-Utf8 (Join-Path $root 'src/Modules/Sales/Sales.Application/IOrderRepository.cs') 'namespace Sales.Application; public interface IOrderRepository {}'

    Write-Utf8 (Join-Path $root 'src/Modules/Sales/Sales.Infrastructure/Sales.Infrastructure.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../Sales.Application/Sales.Application.csproj" /></ItemGroup><ItemGroup><PackageReference Include="Microsoft.Azure.AppConfiguration.AspNetCore" /><PackageReference Include="Azure.Identity" /></ItemGroup></Project>'
    Write-Utf8 (Join-Path $root 'src/Modules/Sales/Sales.Infrastructure/Store.cs') 'namespace Sales.Infrastructure; public sealed class Store {}'

    Write-Utf8 (Join-Path $root 'src/Modules/Sales/Sales.Presentation/Sales.Presentation.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../Sales.Application/Sales.Application.csproj" /></ItemGroup></Project>'
    Write-Utf8 (Join-Path $root 'src/Modules/Sales/Sales.Presentation/Endpoints.cs') 'app.MapGet("/orders", () => 1); services.AddProblemDetails(); public sealed class SalesKnownExceptionHandler : IExceptionHandler {}'

    Write-Utf8 (Join-Path $root 'src/Common/Common.Presentation/Common.Presentation.csproj') '<Project Sdk="Microsoft.NET.Sdk" />'

    Write-Utf8 (Join-Path $root 'src/App.Server/App.Server.csproj') '<Project Sdk="Microsoft.NET.Sdk.Web"><ItemGroup><ProjectReference Include="../Modules/Sales/Sales.Presentation/Sales.Presentation.csproj" /></ItemGroup></Project>'
    Write-Utf8 (Join-Path $root 'src/App.Server/Program.cs') 'opts.DurabilityMode = DurabilityMode.MediatorOnly; builder.Configuration.AddAzureAppConfiguration(o => o.Connect(new Uri(config["AppConfigEndpoint"]), new DefaultAzureCredential())); services.AddProblemDetails(); class GlobalFallbackExceptionHandler : IExceptionHandler { public bool TryHandleAsync(HttpContext context, Exception ex, CancellationToken token) { return true; } }'

    Write-Utf8 (Join-Path $root 'tests/UnitTests/Sales.UnitTests/Sales.UnitTests.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../../../src/Modules/Sales/Sales.Application/Sales.Application.csproj" /></ItemGroup></Project>'

    if (-not $NoSpecs) {
        Write-Utf8 (Join-Path $root 'openspec/specs/sales/contracts/openapi.yaml') "openapi: 3.1.0`ninfo:`n  title: Fixture`n  version: 1.0.0`npaths: {}"
    }

    [void](New-EvidenceFile $root)
    return $root
}

function Invoke-Guard {
    param(
        [string]$Root,
        [switch]$UseEvidence,
        [hashtable]$Environment
    )

    $backup = @{}
    try {
        if ($Environment) {
            foreach ($key in $Environment.Keys) {
                $backup[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
                [Environment]::SetEnvironmentVariable($key, [string]$Environment[$key], 'Process')
            }
        }

        if ($UseEvidence) {
            & $guard -ProjectRoot $Root -EvidencePath (Join-Path $Root 'evidence.json') *> $null
        } else {
            & $guard -ProjectRoot $Root *> $null
        }
        return $LASTEXITCODE
    }
    finally {
        if ($Environment) {
            foreach ($key in $Environment.Keys) {
                [Environment]::SetEnvironmentVariable($key, $backup[$key], 'Process')
            }
        }
    }
}

function Get-GuardReport {
    param([string]$Root)
    $path = Join-Path $Root 'artifacts/sdd-guard/guard-result.json'
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Get-Check {
    param([object]$Report, [string]$Id)
    return $Report.checks | Where-Object id -eq $Id | Select-Object -First 1
}

function Assert-Case {
    param(
        [string]$Name,
        [scriptblock]$Arrange,
        [switch]$UseEvidence,
        [int]$ExpectedExit,
        [string]$CheckId,
        [string[]]$ExpectedStatuses,
        [scriptblock]$ExtraAssert
    )

    try {
        $root = New-Fixture $Name
        $invokeEnvironment = & $Arrange $root
        $exitCode = Invoke-Guard -Root $root -UseEvidence:$UseEvidence -Environment $invokeEnvironment
        $report = Get-GuardReport $root
        $check = Get-Check $report $CheckId

        if ($exitCode -ne $ExpectedExit) {
            throw "Expected exit code $ExpectedExit but got $exitCode."
        }
        if (-not $check) {
            throw "Check $CheckId not found."
        }
        if ($ExpectedStatuses -and $check.status -notin $ExpectedStatuses) {
            throw "Check $CheckId expected status [$($ExpectedStatuses -join ', ')] but got $($check.status)."
        }

        if ($ExtraAssert) {
            & $ExtraAssert $root $report $check
        }

        $script:Passed++
        Write-Output "PASS $Name"
    }
    catch {
        $script:Failed++
        Write-Output "FAIL $Name - $($_.Exception.Message)"
    }
}

function Install-DotnetMock {
    param(
        [string]$Root,
        [int]$RestoreExit = 0,
        [int]$BuildExit = 0,
        [int]$TestExit = 0
    )

    $mockRoot = Join-Path $Root 'tools/mockbin'
    New-Item -ItemType Directory -Path $mockRoot -Force | Out-Null

    $mockScript = @'

$logPath = $env:MOCK_DOTNET_LOG
if ($logPath) {
    Add-Content -LiteralPath $logPath -Encoding utf8 -Value (($args | ForEach-Object { $_.Replace("`t", " ") }) -join "`t")
}

$command = if ($args.Count -gt 0) { $args[0] } else { '' }
if ($command -eq 'restore') {
    exit ([int]$env:MOCK_DOTNET_RESTORE_EXIT)
}
if ($command -eq 'build') {
    exit ([int]$env:MOCK_DOTNET_BUILD_EXIT)
}
if ($command -eq 'test') {
    $resultsDirectory = $null
    for ($index = 0; $index -lt $args.Count; $index++) {
        if ($args[$index] -eq '--results-directory' -and ($index + 1) -lt $args.Count) {
            $resultsDirectory = $args[$index + 1]
            break
        }
    }

    if (-not $resultsDirectory) {
        $rawRoot = Join-Path (Get-Location) 'artifacts/sdd-guard/raw'
        if (Test-Path -LiteralPath $rawRoot) {
            $latestRun = Get-ChildItem -LiteralPath $rawRoot -Directory -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
            if ($latestRun) {
                $resultsDirectory = $latestRun.FullName
            }
        }
    }

    if ($resultsDirectory) {
        New-Item -ItemType Directory -Path $resultsDirectory -Force | Out-Null
        $trx = @"
<?xml version="1.0" encoding="utf-8"?>
<TestRun>
  <ResultSummary>
    <Counters executed="11" passed="11" failed="0" notExecuted="0" />
  </ResultSummary>
</TestRun>
"@
        $coverage = @"
<?xml version="1.0" encoding="utf-8"?>
<coverage>
  <packages>
    <package name="Sales.Domain">
      <classes>
        <class>
          <lines>
            <line number="1" hits="1" />
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
"@
        Set-Content -LiteralPath (Join-Path $resultsDirectory 'mock-results.trx') -Value $trx -Encoding utf8
        Set-Content -LiteralPath (Join-Path $resultsDirectory 'coverage.cobertura.xml') -Value $coverage -Encoding utf8
    }

    exit ([int]$env:MOCK_DOTNET_TEST_EXIT)
}

exit 0
'@

    Write-Utf8 (Join-Path $mockRoot 'dotnet.ps1') $mockScript

    $cmd = @'
@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0dotnet.ps1" %*
exit /b %ERRORLEVEL%
'@
    Write-Utf8 (Join-Path $mockRoot 'dotnet.cmd') $cmd

    $envConfig = @{
        PATH = [Environment]::GetEnvironmentVariable('PATH', 'Process')
        SDD_GUARD_DOTNET_PATH = (Join-Path $mockRoot 'dotnet.ps1')
        MOCK_DOTNET_LOG = (Join-Path $Root 'dotnet-invocations.log')
        MOCK_DOTNET_RESTORE_EXIT = [string]$RestoreExit
        MOCK_DOTNET_BUILD_EXIT = [string]$BuildExit
        MOCK_DOTNET_TEST_EXIT = [string]$TestExit
    }

    return $envConfig
}

function Install-ExternalMocks {
    param(
        [string]$Root,
        [int]$RestoreExit = 0,
        [int]$BuildExit = 0,
        [int]$TestExit = 0
    )

    $envConfig = Install-DotnetMock -Root $Root -RestoreExit $RestoreExit -BuildExit $BuildExit -TestExit $TestExit
    $mockRoot = Join-Path $Root 'tools/mockbin'
    $npxScript = @'
$contractPath = if ($args.Count -gt 0) { $args[$args.Count - 1] } else { '' }
if ($contractPath -and (Test-Path -LiteralPath $contractPath) -and
    (Get-Content -LiteralPath $contractPath -Raw) -match 'INVALID_OPENAPI_FIXTURE') {
    exit 1
}
exit 0
'@
    Write-Utf8 (Join-Path $mockRoot 'npx.ps1') $npxScript
    $envConfig.SDD_GUARD_NPX_PATH = Join-Path $mockRoot 'npx.ps1'
    return $envConfig
}

function Invoke-RepositoryScanFixture {
    param(
        [string]$Name,
        [string]$Content
    )

    $root = Join-Path $tempRoot $Name
    Write-Utf8 (Join-Path $root 'openspec/config.yaml') 'schema: dotnet-sdd'
    New-Item -ItemType Directory -Path (Join-Path $root 'PoCFinal') -Force | Out-Null
    Write-Utf8 (Join-Path $root 'tools/dotnet-sdd-guard/Invoke-DotNetSddGuard.ps1') 'param([string]$ProjectRoot, [string]$ContractRoot, [switch]$VerboseDiagnostics) exit 0'
    Write-Utf8 (Join-Path $root 'src/scan-fixture.md') $Content

    $mockRoot = Join-Path $root 'tools/mockbin'
    Write-Utf8 (Join-Path $mockRoot 'openspec.cmd') "@echo off`r`nexit /b 0"
    $originalPath = [Environment]::GetEnvironmentVariable('PATH', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('PATH', "$mockRoot;$originalPath", 'Process')
        & (Get-Process -Id $PID).Path -NoProfile -File $repositoryGuard -RepositoryRoot $root *> $null
        return $LASTEXITCODE
    }
    finally {
        [Environment]::SetEnvironmentVariable('PATH', $originalPath, 'Process')
    }
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    Assert-Case 'openapi-historical-only-fails-http' {
        param($r)
        Remove-Item -LiteralPath (Join-Path $r 'openspec/specs/sales/contracts/openapi.yaml') -Force
        Write-Utf8 (Join-Path $r 'docs/sdd-history/spec-kit/001/contracts/openapi.yaml') "openapi: 3.1.0`ninfo:`n  title: Historical`n  version: 1.0.0`npaths: {}"
    } -UseEvidence -ExpectedExit 1 -CheckId 'OPENAPI001' -ExpectedStatuses @('FAIL')

    Assert-Case 'openapi-active-valid-passes' {
        param($r)
    } -UseEvidence -ExpectedExit 0 -CheckId 'OPENAPI001' -ExpectedStatuses @('PASS')

    Assert-Case 'openapi-active-invalid-fails' {
        param($r)
        Write-Utf8 (Join-Path $r 'openspec/specs/sales/contracts/openapi.yaml') 'INVALID_OPENAPI_FIXTURE'
        return (Install-ExternalMocks -Root $r)
    } -UseEvidence:$false -ExpectedExit 1 -CheckId 'OPENAPI001' -ExpectedStatuses @('FAIL')

    Assert-Case 'openapi-invalid-history-is-ignored' {
        param($r)
        Write-Utf8 (Join-Path $r 'docs/sdd-history/spec-kit/001/contracts/openapi.yaml') 'INVALID_OPENAPI_FIXTURE'
    } -UseEvidence -ExpectedExit 0 -CheckId 'OPENAPI001' -ExpectedStatuses @('PASS')

    Assert-Case 'openapi-non-http-without-contract-is-not-applicable' {
        param($r)
        Remove-Item -LiteralPath (Join-Path $r 'openspec/specs/sales/contracts/openapi.yaml') -Force
        Remove-Item -LiteralPath (Join-Path $r 'src/Modules/Sales/Sales.Presentation/Endpoints.cs') -Force
        Write-Utf8 (Join-Path $r 'src/App.Server/App.Server.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../Modules/Sales/Sales.Presentation/Sales.Presentation.csproj" /></ItemGroup></Project>'
    } -UseEvidence -ExpectedExit 0 -CheckId 'OPENAPI001' -ExpectedStatuses @('NOT_APPLICABLE')

    try {
        $localMarkers = @(
            ('C:' + '\Users\scan-user\'),
            ('C:' + '/Users/scan-user/'),
            ('file' + '://'),
            ('local' + 'host'),
            ('127' + '.0.0.1'),
            ('[' + '::1]')
        ) -join "`n"
        $scanExit = Invoke-RepositoryScanFixture -Name 'local-scan-detects-all-markers' -Content $localMarkers
        if ($scanExit -ne 1) { throw "Expected scanner exit 1 but got $scanExit." }
        $script:Passed++
        Write-Output 'PASS local-scan-detects-all-markers'
    } catch {
        $script:Failed++
        Write-Output "FAIL local-scan-detects-all-markers - $($_.Exception.Message)"
    }

    try {
        $regexDocumentation = 'Regex documentation may describe a drive prefix, a Users segment, or loopback tokens as separate fragments.'
        $scanExit = Invoke-RepositoryScanFixture -Name 'local-scan-ignores-regex-documentation' -Content $regexDocumentation
        if ($scanExit -ne 0) { throw "Expected scanner exit 0 but got $scanExit." }
        $script:Passed++
        Write-Output 'PASS local-scan-ignores-regex-documentation'
    } catch {
        $script:Failed++
        Write-Output "FAIL local-scan-ignores-regex-documentation - $($_.Exception.Message)"
    }

    Assert-Case 'arch-presentation-to-application-pass' { param($r) } -UseEvidence -ExpectedExit 0 -CheckId 'ARCH001' -ExpectedStatuses @('PASS')

    Assert-Case 'arch-presentation-to-same-module-infrastructure-pass' {
        param($r)
        Write-Utf8 (Join-Path $r 'src/Modules/Sales/Sales.Presentation/Sales.Presentation.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../Sales.Infrastructure/Sales.Infrastructure.csproj" /></ItemGroup></Project>'
    } -UseEvidence -ExpectedExit 0 -CheckId 'ARCH001' -ExpectedStatuses @('PASS')

    Assert-Case 'arch-infrastructure-to-application-pass' { param($r) } -UseEvidence -ExpectedExit 0 -CheckId 'ARCH001' -ExpectedStatuses @('PASS')

    Assert-Case 'arch-application-to-infrastructure-fail' {
        param($r)
        Write-Utf8 (Join-Path $r 'src/Modules/Sales/Sales.Application/Sales.Application.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../Sales.Domain/Sales.Domain.csproj" /><ProjectReference Include="../Sales.Infrastructure/Sales.Infrastructure.csproj" /></ItemGroup></Project>'
    } -UseEvidence -ExpectedExit 1 -CheckId 'ARCH001' -ExpectedStatuses @('FAIL')

    Assert-Case 'arch-cross-module-presentation-to-application-fail' {
        param($r)
        Write-Utf8 (Join-Path $r 'src/Modules/Billing/Billing.Application/Billing.Application.csproj') '<Project Sdk="Microsoft.NET.Sdk" />'
        Write-Utf8 (Join-Path $r 'src/Modules/Sales/Sales.Presentation/Sales.Presentation.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../../Billing/Billing.Application/Billing.Application.csproj" /></ItemGroup></Project>'
    } -UseEvidence -ExpectedExit 1 -CheckId 'ARCH001' -ExpectedStatuses @('FAIL')

    Assert-Case 'arch-common-to-module-fail' {
        param($r)
        Write-Utf8 (Join-Path $r 'src/Common/Common.Presentation/Common.Presentation.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../../Modules/Sales/Sales.Presentation/Sales.Presentation.csproj" /></ItemGroup></Project>'
    } -UseEvidence -ExpectedExit 1 -CheckId 'ARCH001' -ExpectedStatuses @('FAIL')

    Assert-Case 'mig-docs-text-ignored' {
        param($r)
        Write-Utf8 (Join-Path $r 'docs/notes.md') 'dotnet ef migrations add Initial and EnsureCreated();'
    } -UseEvidence -ExpectedExit 0 -CheckId 'MIG001' -ExpectedStatuses @('PASS')

    Assert-Case 'mig-openspec-text-ignored' {
        param($r)
        Write-Utf8 (Join-Path $r 'openspec/schemas/example/template.md') 'Microsoft.EntityFrameworkCore.Design and dotnet ef database update'
    } -UseEvidence -ExpectedExit 0 -CheckId 'MIG001' -ExpectedStatuses @('PASS')

    Assert-Case 'mig-ensurecreated-detected' {
        param($r)
        Write-Utf8 (Join-Path $r 'src/Modules/Sales/Sales.Infrastructure/Init.cs') 'db.Database.EnsureCreated();'
    } -UseEvidence -ExpectedExit 1 -CheckId 'MIG001' -ExpectedStatuses @('FAIL')

    Assert-Case 'test001-ignores-historical-trx' {
        param($r)
        $old = Join-Path $r 'artifacts/sdd-guard/raw/old-run'
        New-Item -ItemType Directory -Path $old -Force | Out-Null
        Write-Utf8 (Join-Path $old 'historical.trx') '<?xml version="1.0" encoding="utf-8"?><TestRun><ResultSummary><Counters executed="11" passed="11" failed="0" notExecuted="0" /></ResultSummary></TestRun>'
        return (Install-ExternalMocks -Root $r -RestoreExit 0 -BuildExit 0 -TestExit 0)
    } -UseEvidence:$false -ExpectedExit 0 -CheckId 'TEST001' -ExpectedStatuses @('PASS') -ExtraAssert {
        param($r, $report, $check)
        if ($check.evidence -notmatch 'executed=11; passed=11; failed=0; skipped=0') {
            throw "TEST001 evidence did not isolate current run: $($check.evidence)"
        }
    }

    Assert-Case 'test001-new-run-ignores-previous-raw' {
        param($r)
        return (Install-ExternalMocks -Root $r -RestoreExit 0 -BuildExit 0 -TestExit 0)
    } -UseEvidence:$false -ExpectedExit 0 -CheckId 'TEST001' -ExpectedStatuses @('PASS') -ExtraAssert {
        param($r, $report, $check)
        if ($check.evidence -notmatch 'executed=11; passed=11; failed=0; skipped=0') {
            throw "First run evidence unexpected: $($check.evidence)"
        }

        $envConfig = Install-ExternalMocks -Root $r -RestoreExit 0 -BuildExit 0 -TestExit 0
        $second = Invoke-Guard -Root $r -Environment $envConfig
        if ($second -ne 0) { throw "Second run failed with code $second." }
        $secondReport = Get-GuardReport $r
        $secondCheck = Get-Check $secondReport 'TEST001'
        if ($secondCheck.evidence -notmatch 'executed=11; passed=11; failed=0; skipped=0') {
            throw "Second run evidence unexpected: $($secondCheck.evidence)"
        }
    }

    Assert-Case 'exc-specific-before-global-pass' {
        param($r)
        Write-Utf8 (Join-Path $r 'src/App.Server/Program.cs') @'
services.AddExceptionHandler<SalesKnownExceptionHandler>();
services.AddExceptionHandler<GlobalFallbackExceptionHandler>();
public sealed class SalesKnownException : Exception { }
public sealed class SalesKnownExceptionHandler : IExceptionHandler {
    public ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken cancellationToken) {
        if (exception is not SalesKnownException) {
            return ValueTask.FromResult(false);
        }

        return ValueTask.FromResult(true);
    }
}
public sealed class GlobalFallbackExceptionHandler : IExceptionHandler {
    public ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken cancellationToken) {
        context.Response.StatusCode = 500;
        return ValueTask.FromResult(true);
    }
}
opts.DurabilityMode = DurabilityMode.MediatorOnly;
builder.Configuration.AddAzureAppConfiguration(o => o.Connect(new Uri(config["AppConfigEndpoint"]), new DefaultAzureCredential()));
services.AddProblemDetails();
'@
    } -UseEvidence -ExpectedExit 0 -CheckId 'EXC001' -ExpectedStatuses @('PASS') -ExtraAssert {
        param($r, $report, $check)
        if ($check.severity -ne 'HARD') {
            throw "EXC001 PASS must be HARD but got $($check.severity)."
        }
    }

    Assert-Case 'exc-global-before-specific-fail' {
        param($r)
        Write-Utf8 (Join-Path $r 'src/App.Server/Program.cs') @'
services.AddExceptionHandler<GlobalFallbackExceptionHandler>();
services.AddExceptionHandler<SalesKnownExceptionHandler>();
public sealed class SalesKnownException : Exception { }
public sealed class SalesKnownExceptionHandler : IExceptionHandler {
    public ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken cancellationToken) {
        if (exception is not SalesKnownException) {
            return ValueTask.FromResult(false);
        }

        return ValueTask.FromResult(true);
    }
}
public sealed class GlobalFallbackExceptionHandler : IExceptionHandler {
    public ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken cancellationToken) {
        context.Response.StatusCode = 500;
        return ValueTask.FromResult(true);
    }
}
opts.DurabilityMode = DurabilityMode.MediatorOnly;
builder.Configuration.AddAzureAppConfiguration(o => o.Connect(new Uri(config["AppConfigEndpoint"]), new DefaultAzureCredential()));
services.AddProblemDetails();
'@
    } -UseEvidence -ExpectedExit 1 -CheckId 'EXC001' -ExpectedStatuses @('FAIL') -ExtraAssert {
        param($r, $report, $check)
        if ($check.severity -ne 'HARD') {
            throw "EXC001 FAIL must be HARD but got $($check.severity)."
        }
    }

    Assert-Case 'exc-guarded-specific-remains-specific' {
        param($r)
        Write-Utf8 (Join-Path $r 'src/App.Server/Program.cs') @'
services.AddExceptionHandler<GlobalFallbackExceptionHandler>();
services.AddExceptionHandler<SalesKnownExceptionHandler>();
public sealed class SalesKnownException : Exception { }
public sealed class SalesKnownExceptionHandler : IExceptionHandler {
    public ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken cancellationToken) {
        if (exception is not SalesKnownException) {
            return ValueTask.FromResult(false);
        }
        return ValueTask.FromResult(true);
    }
}
public sealed class GlobalFallbackExceptionHandler : IExceptionHandler {
    public ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken cancellationToken) {
        context.Response.StatusCode = 500;
        return ValueTask.FromResult(true);
    }
}
opts.DurabilityMode = DurabilityMode.MediatorOnly;
builder.Configuration.AddAzureAppConfiguration(o => o.Connect(new Uri(config["AppConfigEndpoint"]), new DefaultAzureCredential()));
services.AddProblemDetails();
'@
    } -UseEvidence -ExpectedExit 1 -CheckId 'EXC001' -ExpectedStatuses @('FAIL') -ExtraAssert {
        param($r, $report, $check)
        if ($check.severity -ne 'HARD') {
            throw "EXC001 FAIL must be HARD but got $($check.severity)."
        }
    }

    Assert-Case 'exc-order-uncertain-advisory' {
        param($r)
        Write-Utf8 (Join-Path $r 'src/Modules/Sales/Sales.Presentation/ExceptionRegistration.cs') @'
public static class ExceptionRegistration {
    public static IServiceCollection AddSalesPresentation(this IServiceCollection services) {
        services.AddExceptionHandler<GlobalFallbackExceptionHandler>();
        services.AddExceptionHandler<SalesKnownExceptionHandler>();
        return services;
    }
}
public sealed class SalesKnownException : Exception { }
public sealed class SalesKnownExceptionHandler : IExceptionHandler {
    public ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken cancellationToken) {
        if (exception is not SalesKnownException) {
            return ValueTask.FromResult(false);
        }

        return ValueTask.FromResult(true);
    }
}
public sealed class GlobalFallbackExceptionHandler : IExceptionHandler {
    public ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken cancellationToken) {
        context.Response.StatusCode = 500;
        return ValueTask.FromResult(true);
    }
}
'@
        Write-Utf8 (Join-Path $r 'src/App.Server/Program.cs') @'
services.AddSalesPresentation();
opts.DurabilityMode = DurabilityMode.MediatorOnly;
builder.Configuration.AddAzureAppConfiguration(o => o.Connect(new Uri(config["AppConfigEndpoint"]), new DefaultAzureCredential()));
services.AddProblemDetails();
'@
    } -UseEvidence -ExpectedExit 0 -CheckId 'EXC001' -ExpectedStatuses @('ADVISORY') -ExtraAssert {
        param($r, $report, $check)
        if ($check.severity -ne 'ADVISORY') {
            throw "EXC001 ADVISORY must keep ADVISORY severity but got $($check.severity)."
        }
    }

    Assert-Case 'persist002-doc-marker-does-not-pass' {
        param($r)
        Remove-Item -LiteralPath (Join-Path $r 'src/Modules/Sales/Sales.Application/IOrderRepository.cs') -Force
        Write-Utf8 (Join-Path $r 'docs/repository-guidance.md') 'Create IOrderRepository for abstraction.'
    } -UseEvidence -ExpectedExit 0 -CheckId 'PERSIST002' -ExpectedStatuses @('ADVISORY')

    Assert-Case 'wolv-doc-marker-does-not-pass' {
        param($r)
        Write-Utf8 (Join-Path $r 'src/Modules/Sales/Sales.Application/Sales.Application.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../Sales.Domain/Sales.Domain.csproj" /></ItemGroup></Project>'
        Write-Utf8 (Join-Path $r 'src/App.Server/Program.cs') 'builder.Configuration.AddAzureAppConfiguration(o => o.Connect(new Uri(config["AppConfigEndpoint"]), new DefaultAzureCredential())); services.AddProblemDetails(); class GlobalFallbackExceptionHandler : IExceptionHandler { public bool TryHandleAsync(HttpContext context, Exception ex, CancellationToken token) { return true; } }'
        Write-Utf8 (Join-Path $r 'docs/wolverine-notes.md') 'WolverineFx DurabilityMode.MediatorOnly WolverineFx.RabbitMQ'
    } -UseEvidence -ExpectedExit 1 -CheckId 'WOLV001' -ExpectedStatuses @('FAIL') -ExtraAssert {
        param($r, $report, $check)
        $check2 = Get-Check $report 'WOLV002'
        if (-not $check2 -or $check2.status -ne 'FAIL') {
            throw 'WOLV002 should fail when MediatorOnly only appears in documentation.'
        }
    }

    Assert-Case 'azure-doc-marker-does-not-pass' {
        param($r)
        Write-Utf8 (Join-Path $r 'src/Modules/Sales/Sales.Infrastructure/Sales.Infrastructure.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../Sales.Application/Sales.Application.csproj" /></ItemGroup></Project>'
        Write-Utf8 (Join-Path $r 'src/App.Server/Program.cs') 'opts.DurabilityMode = DurabilityMode.MediatorOnly; services.AddProblemDetails(); class GlobalFallbackExceptionHandler : IExceptionHandler { public bool TryHandleAsync(HttpContext context, Exception ex, CancellationToken token) { return true; } }'
        Write-Utf8 (Join-Path $r 'specs/001/research.md') 'Microsoft.Azure.AppConfiguration.AspNetCore Azure.Identity AddAzureAppConfiguration(DefaultAzureCredential())'
    } -UseEvidence -ExpectedExit 1 -CheckId 'AZURE001' -ExpectedStatuses @('FAIL')

    Assert-Case 'http-doc-marker-does-not-pass' {
        param($r)
        Write-Utf8 (Join-Path $r 'src/Modules/Sales/Sales.Presentation/Endpoints.cs') 'app.MapGet("/orders", () => 1);'
        Write-Utf8 (Join-Path $r 'src/App.Server/Program.cs') 'opts.DurabilityMode = DurabilityMode.MediatorOnly; builder.Configuration.AddAzureAppConfiguration(o => o.Connect(new Uri(config["AppConfigEndpoint"]), new DefaultAzureCredential()));'
        Write-Utf8 (Join-Path $r 'openspec/schemas/example/http-template.md') 'Use AddProblemDetails() and implement IExceptionHandler.'
    } -UseEvidence -ExpectedExit 1 -CheckId 'HTTP001' -ExpectedStatuses @('FAIL')

    Assert-Case 'invoke-external-preserves-exit-and-coverage-args' {
        param($r)
        return (Install-ExternalMocks -Root $r -RestoreExit 0 -BuildExit 0 -TestExit 7)
    } -UseEvidence:$false -ExpectedExit 1 -CheckId 'TEST001' -ExpectedStatuses @('FAIL') -ExtraAssert {
        param($r, $report, $check)
        $log = Get-Content -LiteralPath (Join-Path $r 'dotnet-invocations.log') -Raw
        if ($log -notmatch '--collect:XPlat Code Coverage') {
            throw 'Coverage collection argument was not forwarded to dotnet test.'
        }
        if ($log -notmatch 'trx;LogFilePrefix=sdd-guard-1') {
            throw 'TRX logger argument was not forwarded to dotnet test.'
        }
        if ($log -notmatch '--results-directory') {
            throw 'Results directory argument was not forwarded to dotnet test.'
        }
    }

    $schemaRoot = New-Fixture 'report-schema'
    [void](Invoke-Guard -Root $schemaRoot -UseEvidence)
    $schemaReport = Get-GuardReport $schemaRoot
    if ($schemaReport.schemaVersion -eq '1.0' -and $schemaReport.guard.id -eq 'dotnet-sdd-guard' -and $schemaReport.guard.version -eq '2.0.0' -and $schemaReport.summary -and $schemaReport.checks.Count -gt 0) {
        $script:Passed++
        Write-Output 'PASS report-json-schema'
    } else {
        $script:Failed++
        Write-Output 'FAIL report-json-schema'
    }

    $secretRoot = New-Fixture 'sanitization'
    Write-Utf8 (Join-Path $secretRoot 'src/secret.cs') 'var token = "super-secret-value"; var path = "LOCAL_ABSOLUTE_PATH_FIXTURE";'
    [void](Invoke-Guard -Root $secretRoot -UseEvidence)
    $exports = (Get-Content -LiteralPath (Join-Path $secretRoot 'artifacts/sdd-guard/guard-result.json') -Raw) +
        (Get-Content -LiteralPath (Join-Path $secretRoot 'artifacts/sdd-guard/guard-result.md') -Raw)
    if ($exports -notmatch 'super-secret-value|LOCAL_ABSOLUTE_PATH_FIXTURE') {
        $script:Passed++
        Write-Output 'PASS sanitization'
    } else {
        $script:Failed++
        Write-Output 'FAIL sanitization'
    }

    if ($script:Failed -gt 0) {
        Write-Output "GUARD TESTS FAILED: passed=$script:Passed failed=$script:Failed"
        exit 1
    }

    Write-Output "ALL GUARD TESTS PASS: $script:Passed"
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
