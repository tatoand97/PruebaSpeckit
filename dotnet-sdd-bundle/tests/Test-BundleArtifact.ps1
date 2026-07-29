[CmdletBinding()]
param(
    [string]$ArtifactPath = (Join-Path $PSScriptRoot '../dist/dotnet-sdd-1.0.0.zip')
)

$ErrorActionPreference = 'Stop'
$artifact = [System.IO.Path]::GetFullPath($ArtifactPath)
if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
    throw "Bundle artifact was not found."
}

$archive = [System.IO.Compression.ZipFile]::OpenRead($artifact)
try {
    $names = @($archive.Entries | ForEach-Object FullName)
    foreach ($required in @('bundle.yml', 'README.md', 'CHANGELOG.md', 'SPEC-KIT-0.14.3-LIMITATION.md')) {
        if ($required -notin $names) { throw "Artifact is missing $required." }
    }
    if ($names -match 'dotnet-sdd-harness|poc|codex|C:|Users/') {
        throw 'Artifact contains a prohibited path or component.'
    }

    $manifestEntry = $archive.GetEntry('bundle.yml')
    $reader = [System.IO.StreamReader]::new($manifestEntry.Open())
    try { $manifest = $reader.ReadToEnd() } finally { $reader.Dispose() }
    foreach ($pin in @(
        'id: "dotnet-sdd-guard"', 'version: "1.0.0"',
        'id: "dotnet-sdd"', 'version: "1.0.1"',
        'id: "dotnet-sdd-feature"', 'version: "0.1.0"'
    )) {
        if ($manifest -notmatch [regex]::Escape($pin)) { throw "Missing pinned component declaration." }
    }
    if ($manifest -match '(?mi)^integration:') { throw 'Bundle must remain integration-agnostic.' }
}
finally {
    $archive.Dispose()
}

Write-Output 'BUNDLE ARTIFACT STATIC TEST PASS'
exit 0
