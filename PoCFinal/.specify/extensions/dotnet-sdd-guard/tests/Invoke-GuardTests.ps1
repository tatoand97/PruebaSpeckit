[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$guard = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/Invoke-SddGuard.ps1')).Path
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("dotnet-sdd-guard-tests-" + [guid]::NewGuid().ToString('N'))
$script:Passed = 0
$script:Failed = 0

function Write-Utf8 {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8NoBOM
}

function New-Fixture {
    param([string]$Name)
    $root = Join-Path $tempRoot $Name
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    Write-Utf8 (Join-Path $root 'Fixture.slnx') '<Solution />'
    Write-Utf8 (Join-Path $root 'global.json') '{"sdk":{"version":"10.0.100"}}'
    Write-Utf8 (Join-Path $root 'Directory.Build.props') '<Project><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>'
    Write-Utf8 (Join-Path $root 'src/Modules/Sales/Sales.Domain/Sales.Domain.csproj') '<Project Sdk="Microsoft.NET.Sdk" />'
    Write-Utf8 (Join-Path $root 'src/Modules/Sales/Sales.Domain/Order.cs') 'namespace Sales.Domain; public sealed class Order {}'
    Write-Utf8 (Join-Path $root 'src/Modules/Sales/Sales.Application/Sales.Application.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../Sales.Domain/Sales.Domain.csproj" /></ItemGroup><ItemGroup><PackageReference Include="WolverineFx" /></ItemGroup></Project>'
    Write-Utf8 (Join-Path $root 'src/Modules/Sales/Sales.Application/IOrderRepository.cs') 'public interface IOrderRepository {}'
    Write-Utf8 (Join-Path $root 'src/Modules/Sales/Sales.Infrastructure/Sales.Infrastructure.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../Sales.Application/Sales.Application.csproj" /></ItemGroup><ItemGroup><PackageReference Include="Microsoft.Azure.AppConfiguration.AspNetCore" /><PackageReference Include="Azure.Identity" /></ItemGroup></Project>'
    Write-Utf8 (Join-Path $root 'src/Modules/Sales/Sales.Presentation/Sales.Presentation.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../Sales.Infrastructure/Sales.Infrastructure.csproj" /></ItemGroup></Project>'
    Write-Utf8 (Join-Path $root 'src/Modules/Sales/Sales.Presentation/Endpoints.cs') 'app.MapGet("/orders", () => 1); services.AddProblemDetails(); class Errors : IExceptionHandler {}'
    Write-Utf8 (Join-Path $root 'src/App.Server/App.Server.csproj') '<Project Sdk="Microsoft.NET.Sdk.Web"><ItemGroup><ProjectReference Include="../Modules/Sales/Sales.Presentation/Sales.Presentation.csproj" /></ItemGroup></Project>'
    Write-Utf8 (Join-Path $root 'src/App.Server/Program.cs') 'opts.DurabilityMode = DurabilityMode.MediatorOnly; builder.Configuration.AddAzureAppConfiguration(o => o.Connect(new Uri(config["AppConfigEndpoint"]), new DefaultAzureCredential()));'
    Write-Utf8 (Join-Path $root 'specs/001/contracts/openapi.yaml') "openapi: 3.1.0`ninfo:`n  title: Fixture`n  version: 1.0.0`npaths: {}"
    $evidence = [ordered]@{
        restore = $true
        build = $true
        tests = [ordered]@{ ok = $true; counts = [ordered]@{ executed = 4; passed = 4; failed = 0; skipped = 0 } }
        coverage = 85
        openapi = $true
    }
    $evidence | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $root 'evidence.json') -Encoding utf8NoBOM
    return $root
}

function Invoke-Fixture {
    param([string]$Root)
    & $guard -ProjectRoot $Root -EvidencePath (Join-Path $Root 'evidence.json') *> $null
    return $LASTEXITCODE
}

function Assert-Case {
    param([string]$Name, [scriptblock]$Arrange, [int]$ExpectedExit, [string]$ExpectedCheck, [string]$ExpectedStatus)
    try {
        $root = New-Fixture $Name
        & $Arrange $root
        $exitCode = Invoke-Fixture $root
        $report = Get-Content -LiteralPath (Join-Path $root 'artifacts/sdd-guard/guard-result.json') -Raw | ConvertFrom-Json
        $check = $report.checks | Where-Object id -eq $ExpectedCheck
        if ($exitCode -ne $ExpectedExit -or -not $check -or $check.status -ne $ExpectedStatus) {
            throw "exit=$exitCode check=$($check.status)"
        }
        $script:Passed++
        Write-Output "PASS $Name"
    }
    catch {
        $script:Failed++
        Write-Output "FAIL $Name - $($_.Exception.Message)"
    }
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    Assert-Case 'valid-architecture' { param($r) } 0 'ARCH001' 'PASS'
    Assert-Case 'domain-to-infrastructure' {
        param($r)
        Write-Utf8 (Join-Path $r 'src/Modules/Sales/Sales.Domain/Sales.Domain.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../Sales.Infrastructure/Sales.Infrastructure.csproj" /></ItemGroup></Project>'
    } 1 'ARCH001' 'FAIL'
    Assert-Case 'application-dbcontext' {
        param($r)
        Write-Utf8 (Join-Path $r 'src/Modules/Sales/Sales.Application/Leak.cs') 'public sealed class Leak : DbContext {}'
    } 1 'PERSIST001' 'FAIL'
    Assert-Case 'common-presentation-to-module' {
        param($r)
        Write-Utf8 (Join-Path $r 'src/Common/Common.Presentation/Common.Presentation.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../../Modules/Sales/Sales.Presentation/Sales.Presentation.csproj" /></ItemGroup></Project>'
    } 1 'ARCH001' 'FAIL'
    Assert-Case 'migration-directory' { param($r) New-Item -ItemType Directory -Path (Join-Path $r 'src/Modules/Sales/Sales.Infrastructure/Migrations') | Out-Null } 1 'MIG001' 'FAIL'
    Assert-Case 'ef-design' { param($r) Write-Utf8 (Join-Path $r 'src/Modules/Sales/Sales.Infrastructure/Design.csproj') '<Project><ItemGroup><PackageReference Include="Microsoft.EntityFrameworkCore.Design" /></ItemGroup></Project>' } 1 'MIG001' 'FAIL'
    Assert-Case 'dotnet-ef' { param($r) Write-Utf8 (Join-Path $r 'tools.md') 'dotnet-ef' } 1 'MIG001' 'FAIL'
    Assert-Case 'missing-azure' { param($r) Write-Utf8 (Join-Path $r 'src/App.Server/Program.cs') 'opts.DurabilityMode = DurabilityMode.MediatorOnly;' } 1 'AZURE001' 'FAIL'
    Assert-Case 'missing-mediator-only' { param($r) (Get-Content -LiteralPath (Join-Path $r 'src/App.Server/Program.cs') -Raw).Replace('opts.DurabilityMode = DurabilityMode.MediatorOnly;', '') | Set-Content -LiteralPath (Join-Path $r 'src/App.Server/Program.cs') } 1 'WOLV002' 'FAIL'
    Assert-Case 'invalid-openapi' { param($r) $e=Get-Content (Join-Path $r 'evidence.json') -Raw|ConvertFrom-Json; $e.openapi=$false; $e|ConvertTo-Json -Depth 5|Set-Content (Join-Path $r 'evidence.json') } 1 'OPENAPI001' 'FAIL'
    Assert-Case 'coverage-below-80' { param($r) $e=Get-Content (Join-Path $r 'evidence.json') -Raw|ConvertFrom-Json; $e.coverage=79.99; $e|ConvertTo-Json -Depth 5|Set-Content (Join-Path $r 'evidence.json') } 1 'COV001' 'FAIL'
    Assert-Case 'ambiguous-solutions' { param($r) Write-Utf8 (Join-Path $r 'Second.sln') '' } 2 'SDK001' 'PASS'
    Assert-Case 'ensure-created' { param($r) Write-Utf8 (Join-Path $r 'src/Modules/Sales/Sales.Infrastructure/Init.cs') 'db.Database.EnsureCreated();' } 1 'MIG001' 'FAIL'

    $schemaRoot = New-Fixture 'report-schema'
    [void](Invoke-Fixture $schemaRoot)
    $raw = Get-Content -LiteralPath (Join-Path $schemaRoot 'artifacts/sdd-guard/guard-result.json') -Raw
    $report = $raw | ConvertFrom-Json
    if ($report.schemaVersion -eq '1.0' -and $report.guard.id -eq 'dotnet-sdd-guard' -and $report.summary -and $report.checks.Count -gt 0) {
        $script:Passed++; Write-Output 'PASS report-json-schema'
    } else { $script:Failed++; Write-Output 'FAIL report-json-schema' }

    $secretRoot = New-Fixture 'sanitization'
    Write-Utf8 (Join-Path $secretRoot 'src/secret.cs') 'var token = "super-secret-value"; var path = "C:\Users\SecretUser\SecretProject";'
    [void](Invoke-Fixture $secretRoot)
    $exports = (Get-Content -LiteralPath (Join-Path $secretRoot 'artifacts/sdd-guard/guard-result.json') -Raw) +
        (Get-Content -LiteralPath (Join-Path $secretRoot 'artifacts/sdd-guard/guard-result.md') -Raw)
    if ($exports -notmatch 'super-secret-value|SecretUser|SecretProject') {
        $script:Passed++; Write-Output 'PASS sanitization'
    } else { $script:Failed++; Write-Output 'FAIL sanitization' }

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
