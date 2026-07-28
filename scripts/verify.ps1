[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$lockFiles = @(
    (Join-Path $repositoryRoot 'src\Orders.Api\packages.lock.json'),
    (Join-Path $repositoryRoot 'tests\Orders.Api.Tests\packages.lock.json')
)

function Invoke-DotNet {
    param(
        [Parameter(Mandatory)]
        [string[]] $Arguments
    )

    & dotnet @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

function Invoke-TestGate {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Filter
    )

    Write-Host "VERIFY_GATE=$Name"
    Invoke-DotNet -Arguments @(
        'test',
        '.\tests\Orders.Api.Tests\Orders.Api.Tests.csproj',
        '--configuration',
        'Release',
        '--no-build',
        '--filter',
        $Filter
    )
}

$exitCode = 0
Push-Location -LiteralPath $repositoryRoot
try {
    foreach ($lockFile in $lockFiles) {
        if (-not (Test-Path -LiteralPath $lockFile -PathType Leaf)) {
            throw "Required lock file is missing: $lockFile"
        }
    }

    $initialLockHashes = @{}
    foreach ($lockFile in $lockFiles) {
        $initialLockHashes[$lockFile] =
            (Get-FileHash -LiteralPath $lockFile -Algorithm SHA256).Hash
    }

    Write-Host 'VERIFY_GATE=locked_restore'
    Invoke-DotNet -Arguments @('restore', '.\Orders.slnx', '--locked-mode')

    Write-Host 'VERIFY_GATE=release_build'
    Invoke-DotNet -Arguments @(
        'build',
        '.\Orders.slnx',
        '--configuration',
        'Release',
        '--no-restore',
        '-warnaserror'
    )

    Invoke-TestGate -Name 'unit' -Filter 'TestCategory=Validation'
    Invoke-TestGate -Name 'integration' -Filter 'TestCategory=Integration'
    Invoke-TestGate -Name 'contract' -Filter 'TestCategory=Contract&TestCategory!=HostBoundary'
    Invoke-TestGate -Name 'persistence_atomicity' -Filter 'TestCategory=Persistence|TestCategory=Atomicity|TestCategory=Identity'
    Invoke-TestGate -Name 'restart' -Filter 'TestCategory=Restart'
    Invoke-TestGate -Name 'concurrency' -Filter 'TestCategory=Concurrency'
    Invoke-TestGate -Name 'real_kestrel_host_boundary' -Filter 'TestCategory=HostBoundary'
    Invoke-TestGate -Name 'logging_security_sc006' -Filter 'TestCategory=Logging|TestCategory=Security'
    Invoke-TestGate -Name 'sc005_performance' -Filter 'TestCategory=Load'

    Write-Host 'VERIFY_GATE=lock_file_immutability'
    foreach ($lockFile in $lockFiles) {
        $finalHash = (Get-FileHash -LiteralPath $lockFile -Algorithm SHA256).Hash
        if ($finalHash -ne $initialLockHashes[$lockFile]) {
            throw "Lock file changed during verification: $lockFile"
        }
    }

    Write-Host 'VERIFY_RESULT=PASS'
}
catch {
    Write-Error $_
    $exitCode = 1
}
finally {
    Pop-Location
}

exit $exitCode
