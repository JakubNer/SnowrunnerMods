[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9_]+$')]
    [string]$ModName,

    [Parameter(Mandatory)]
    [string]$ConvertedModPath,

    [Parameter(Mandatory)]
    [string]$OutputDirectory,

    [ValidateSet('pc')]
    [string]$Platform = 'pc',

    [Parameter(Mandatory)]
    [switch]$Experimental
)

# Reproduce the observed PC layout of published mod.io packages.
# This packages existing converted resources; it neither runs Convert nor uploads.
# Game schema validation, cache/source provenance and runtime compatibility remain
# the caller's responsibility. Console payloads are deliberately unsupported.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $Experimental) { throw 'Explicit -Experimental acknowledgement is required.' }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$source = (Resolve-Path -LiteralPath $ConvertedModPath).ProviderPath.TrimEnd('\', '/')
$output = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\', '/')
if ($output.Equals($source, [StringComparison]::OrdinalIgnoreCase) -or
    $output.StartsWith($source + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputDirectory must be outside ConvertedModPath.'
}
if (-not (Test-Path -LiteralPath (Join-Path $source 'classes') -PathType Container)) {
    throw 'ConvertedModPath must contain classes.'
}
$sourceFiles = @(Get-ChildItem -LiteralPath $source -Recurse -File -Force)
if (Get-ChildItem -LiteralPath $source -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) {
    throw 'Reparse points are not supported in the input tree.'
}
foreach ($file in $sourceFiles | Where-Object Extension -EQ '.xml') {
    try { [xml]('<validation-root>' + [IO.File]::ReadAllText($file.FullName) + '</validation-root>') | Out-Null }
    catch { throw "Invalid XML fragment '$($file.FullName)': $($_.Exception.Message)" }
}
$common = [Collections.Generic.List[object]]::new()
$textures = [Collections.Generic.List[object]]::new()
$names = @{}
function Add-Payload([Collections.Generic.List[object]]$List, [string]$Path, [string]$Entry) {
    if ($Entry -match '(^/|(^|/)\.\.(/|$))' -or $Entry.Contains(':')) { throw "Unsafe entry: $Entry" }
    if ($names.ContainsKey($Entry)) { throw "Duplicate/flattened resource collision: $Entry" }
    $names[$Entry] = $true
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required payload: $Path" }
    $file = Get-Item -LiteralPath $Path
    if ($file.Length -eq 0) { throw "Empty payload: $Path" }
    $List.Add([pscustomobject]@{ Path=$file.FullName; Entry=$Entry; Bytes=$file.Length; SHA256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash })
}
foreach ($file in $sourceFiles) {
    $relative = $file.FullName.Substring($source.Length + 1).Replace('\', '/')
    if ($relative -match '^classes/.*\.xml$' -or $relative -match '^texts/.*\.str$' -or $relative -match '^ui/.*\.(png|dds|tga)$') {
        Add-Payload $common $file.FullName $relative
    }
}
if (-not ($common | Where-Object { $_.Entry -like 'classes/*' })) { throw 'No class XML payloads found.' }
# Enumerate source assets, not arbitrary cache contents, to exclude stale extras
# and the workaround's duplicate textures_ naming aliases.
foreach ($file in $sourceFiles | Where-Object Extension -EQ '.fbx') {
    $relative = $file.FullName.Substring($source.Length + 1).Replace('\', '/')
    if (-not $relative.StartsWith('meshes/')) { throw "Unsupported FBX location: $relative" }
    $resource = $relative.Substring(7, $relative.Length - 11).Replace('/', '_')
    $entry = "prebuild/meshes/$resource"
    Add-Payload $common (Join-Path $source $entry) $entry
}
foreach ($file in $sourceFiles | Where-Object Extension -EQ '.tga') {
    $relative = $file.FullName.Substring($source.Length + 1).Replace('\', '/')
    if ($relative.StartsWith('ui/')) { continue }
    if (-not $relative.StartsWith('textures/')) { throw "Unsupported TGA location: $relative" }
    $flat = [IO.Path]::ChangeExtension($relative.Substring(9).Replace('/', '_'), 'pct')
    $entry = "prebuild/textures/pct/$flat"
    Add-Payload $textures (Join-Path $source $entry) $entry
}

New-Item -ItemType Directory -Path $output -Force | Out-Null
$package = Join-Path $output ($ModName + '_pc-experimental.zip')
$manifestPath = Join-Path $output ($ModName + '_pc-experimental.manifest.json')
if ((Test-Path -LiteralPath $package) -or (Test-Path -LiteralPath $manifestPath)) { throw 'Output already exists; choose a fresh output directory.' }
$work = Join-Path $output ('.pack-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
function Get-StreamHash([IO.Stream]$Stream) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($Stream)).Replace('-', '') }
    finally { $sha.Dispose() }
}
function Write-VerifiedArchive([string]$Path, [object[]]$Items) {
    $archive = [IO.Compression.ZipFile]::Open($Path, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($item in $Items | Sort-Object Entry) {
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $item.Path, $item.Entry, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    }
    finally { $archive.Dispose() }
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        if ($archive.Entries.Count -ne $Items.Count) { throw 'Archive entry count mismatch.' }
        foreach ($item in $Items) {
            $entry = $archive.GetEntry($item.Entry)
            if (-not $entry -or $entry.Length -ne $item.Bytes) { throw "Archive payload mismatch: $($item.Entry)" }
            $stream = $entry.Open()
            try { if ((Get-StreamHash $stream) -ne $item.SHA256) { throw "Archive hash mismatch: $($item.Entry)" } }
            finally { $stream.Dispose() }
        }
    }
    finally { $archive.Dispose() }
}
try {
    $commonPak = Join-Path $work "$ModName.pak"
    $pcPak = Join-Path $work 'pc.pak'
    Write-VerifiedArchive $commonPak @($common.ToArray())
    if ($textures.Count) { Write-VerifiedArchive $pcPak @($textures.ToArray()) }
    else { [IO.File]::WriteAllBytes($pcPak, [byte[]]@()) } # Observed in published XML-only packages.
    $outer = @(
        [pscustomobject]@{ Path=$commonPak; Entry="$ModName.pak"; Bytes=(Get-Item $commonPak).Length; SHA256=(Get-FileHash $commonPak).Hash },
        [pscustomobject]@{ Path=$pcPak; Entry='pc.pak'; Bytes=(Get-Item $pcPak).Length; SHA256=(Get-FileHash $pcPak).Hash }
    )
    $stagedZip = Join-Path $work 'package.zip'
    Write-VerifiedArchive $stagedZip $outer
    $manifest = [ordered]@{
        ModName=$ModName; Platform=$Platform; Experimental=$true
        RuntimeVerified=$false; SourceCacheProvenanceVerified=$false
        PackageSHA256=(Get-FileHash -LiteralPath $stagedZip).Hash
        Common=@($common.ToArray() | Select-Object Entry,Bytes,SHA256)
        Textures=@($textures.ToArray() | Select-Object Entry,Bytes,SHA256)
        Notes=@('Observed published PC payload layout; ordinary ZIP containers without game-specific padding.',
            'No raw FBX/TGA, DDS caches, NX caches, RebuildLog, or duplicate texture aliases included (UI assets excepted).',
            'Not a console package, game-schema validator, or proof that caches match current source assets.',
            'Test via a separate private/hidden mod.io mod; do not replace an existing published release.')
    }
    $stagedManifest = Join-Path $work 'manifest.json'
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $stagedManifest -Encoding UTF8
    Move-Item -LiteralPath $stagedManifest -Destination $manifestPath
    Move-Item -LiteralPath $stagedZip -Destination $package
    Write-Output "Experimental PC package: $package"
    Write-Output "Common entries: $($common.Count); texture entries: $($textures.Count)"
    Write-Output "SHA256: $($manifest.PackageSHA256)"
    Write-Warning 'Archive hashes verified, but game loading is unverified. No console packages created. No mod deployed or uploaded.'
}
finally { if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force } }
