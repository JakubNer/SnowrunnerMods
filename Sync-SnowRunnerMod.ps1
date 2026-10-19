[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$ModName = 'twinsteer_plus_logs',

    [string]$SnowRunnerMedia = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games\SnowRunner\Media'),

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$source = Join-Path $PSScriptRoot $ModName
if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "Mod source directory does not exist: $source"
}
if (-not (Test-Path -LiteralPath (Join-Path $source 'classes') -PathType Container)) {
    throw "Expected a 'classes' directory at the mod root: $source"
}

$runningGame = Get-Process -Name 'SnowRunner' -ErrorAction SilentlyContinue
if ($runningGame -and -not $Force) {
    throw 'SnowRunner is running. Close it before syncing, or use -Force if you understand the risk.'
}

$modsDirectory = Join-Path $SnowRunnerMedia 'Mods'
$destination = Join-Path $modsDirectory $ModName
$staging = Join-Path $modsDirectory (".$ModName-sync-" + [guid]::NewGuid().ToString('N'))

New-Item -ItemType Directory -Path $modsDirectory -Force | Out-Null
try {
    New-Item -ItemType Directory -Path $staging | Out-Null
    Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $staging -Recurse -Force

    if (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
    Move-Item -LiteralPath $staging -Destination $destination
}
finally {
    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
}

Write-Host "Synced mod source to: $destination"
Write-Host 'Open Summer Proving Grounds, then use Tools > Mod Manager > Convert and Tools > Reload.'
