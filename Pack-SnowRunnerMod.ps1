[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$ModName = 'twinsteer_plus_logs',

    [string]$OutputDirectory = (Join-Path ([System.IO.Path]::GetTempPath()) 'snowrunner-packages'),

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repoRoot = $PSScriptRoot
$source = Join-Path $repoRoot $ModName

if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "Mod directory does not exist: $source"
}

$packageRoots = @(Get-ChildItem -LiteralPath $source -Force)
if ($packageRoots.Count -eq 0) {
    throw "Mod directory is empty: $source"
}

if (-not (Test-Path -LiteralPath (Join-Path $source 'classes') -PathType Container)) {
    throw "Expected a 'classes' directory at the package root: $source"
}

Get-ChildItem -LiteralPath $source -Recurse -File -Filter '*.xml' | ForEach-Object {
    try {
        $fragment = [System.IO.File]::ReadAllText($_.FullName)
        [xml]("<snowrunner-validation-root>$fragment</snowrunner-validation-root>") | Out-Null
    }
    catch {
        throw "Invalid SnowRunner XML fragment '$($_.FullName)': $($_.Exception.Message)"
    }
}

$output = [System.IO.Path]::GetFullPath($OutputDirectory)
$sourcePath = [System.IO.Path]::GetFullPath($source)
if (
    $output.Equals($sourcePath, [System.StringComparison]::OrdinalIgnoreCase) -or
    $output.StartsWith($sourcePath + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
) {
    throw 'OutputDirectory must not be the mod source directory or one of its descendants.'
}

New-Item -ItemType Directory -Path $output -Force | Out-Null
$uploadPath = Join-Path $output "$ModName-layout-check.zip"
if (Test-Path -LiteralPath $uploadPath) {
    if (-not $Force) {
        throw "Package already exists: $uploadPath (use -Force to replace it)"
    }
    Remove-Item -LiteralPath $uploadPath -Force
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("snowrunner-pack-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

try {
    $innerPak = Join-Path $work "$ModName.pak"
    $innerArchive = [System.IO.Compression.ZipFile]::Open(
        $innerPak,
        [System.IO.Compression.ZipArchiveMode]::Create
    )
    try {
        Get-ChildItem -LiteralPath $source -Recurse -File -Force | ForEach-Object {
            $relativePath = $_.FullName.Substring($sourcePath.Length).TrimStart([char[]]@('\', '/'))
            $entryName = $relativePath.Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $innerArchive,
                $_.FullName,
                $entryName,
                [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    }
    finally {
        $innerArchive.Dispose()
    }

    $innerArchive = [System.IO.Compression.ZipFile]::OpenRead($innerPak)
    try {
        $entries = @($innerArchive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
        if (-not ($entries | Where-Object { $_ -like 'classes/*' })) {
            throw "The inner package does not contain files below 'classes/'."
        }
        if ($entries | Where-Object { $_ -like "$ModName/*" }) {
            throw "The inner package incorrectly contains a top-level '$ModName/' directory."
        }
    }
    finally {
        $innerArchive.Dispose()
    }

    $outerArchive = [System.IO.Compression.ZipFile]::Open(
        $uploadPath,
        [System.IO.Compression.ZipArchiveMode]::Create
    )
    try {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $outerArchive,
            $innerPak,
            "$ModName.pak",
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
    finally {
        $outerArchive.Dispose()
    }
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

$hash = (Get-FileHash -LiteralPath $uploadPath -Algorithm SHA256).Hash
Write-Host "Layout-check package: $uploadPath"
Write-Host "SHA256: $hash"
Write-Warning 'Layout-check package only. For releases, use Summer Proving Grounds > Tools > Mod Manager > Pack to create each platform ZIP.'
