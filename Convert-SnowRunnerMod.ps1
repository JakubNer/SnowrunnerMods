[CmdletBinding()]
param(
    [string]$ModName = 'twinsteer_plus_logs',
    [string]$GameBin = 'C:\Program Files\Epic Games\SnowRunner\en_us\Sources\Bin',
    [string]$SnowRunnerMedia = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games\SnowRunner\Media')
)

# Work around resource converter startup failure with in-game backend-auth-params.
# Uses only installed tools; does not modify the game or source textures.
$ErrorActionPreference = 'Stop'
if ($ModName -notmatch '^[a-z0-9_]+$') { throw 'ModName must contain only lowercase letters, digits, and underscores.' }
if (Get-Process -Name SnowRunner -ErrorAction SilentlyContinue) { throw 'Close SnowRunner before converting local resources.' }
$source = Join-Path $PSScriptRoot $ModName
$destination = Join-Path $SnowRunnerMedia "Mods\$ModName"
$converter = Join-Path $GameBin 'SnowrunnerResourceConverter.exe'
if (-not (Test-Path -LiteralPath $converter -PathType Leaf)) { throw "Converter not found: $converter" }
if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw "Mod source not found: $source" }
$pakDirectory = [IO.Path]::GetFullPath((Join-Path $GameBin '..\..\preload\paks\client'))
$stage = Join-Path ([IO.Path]::GetTempPath()) ("snowrunner-convert-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
try {
    Get-ChildItem -LiteralPath $source | Where-Object { $_.Name -notin @('prebuild', 'RebuildLog') } |
        Copy-Item -Destination $stage -Recurse -Force
    Get-ChildItem -LiteralPath $stage -Recurse -Filter '*.xml' | ForEach-Object {
        [xml]("<validation-root>" + (Get-Content -LiteralPath $_.FullName -Raw) + "</validation-root>") | Out-Null
    }
    $common = @('-r', $stage, '--fake-phys-fs', '--mod-convert', '--root-mod-path', $stage)
    foreach ($pak in @('gfx.pak', 'boot.pak', 'initial.pak', 'shader.pak')) {
        $path = Join-Path $pakDirectory $pak
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing installed archive: $path" }
        $common += @('--initial-pak', $path)
    }
    function Invoke-ResourceConversion([string]$InputResource, [string]$OutputResource, [string[]]$ExtraArguments = @()) {
        New-Item -ItemType Directory -Force -Path (Split-Path $OutputResource -Parent) | Out-Null
        Write-Host "Converting $InputResource"
        $messages = & $converter @common @ExtraArguments -i $InputResource -o $OutputResource 2>&1
        $exit = $LASTEXITCODE
        $messages | ForEach-Object { Write-Host $_ }
        # Some resource errors return zero, so inspect diagnostics and output too.
        if ($exit -ne 0 -or -not (Test-Path -LiteralPath $OutputResource -PathType Leaf) -or
            (Get-Item -LiteralPath $OutputResource).Length -eq 0 -or
            (($messages | Out-String) -match 'Failed to load|Unable to run|Could not load|Cant open|failed!')) {
            throw "Resource conversion failed: $InputResource (exit $exit)"
        }
    }
    Push-Location $GameBin
    try {
        $textureRoot = Join-Path $stage 'textures'
        if (Test-Path -LiteralPath $textureRoot) {
            Get-ChildItem -LiteralPath $textureRoot -Recurse -Filter '*.tga' | ForEach-Object {
                $relative = $_.FullName.Substring($textureRoot.Length + 1).Replace('\', '/')
                $flat = [IO.Path]::ChangeExtension($relative.Replace('/', '_'), 'dds')
                $dds = Join-Path $stage "prebuild\textures\dds\$flat"
                Invoke-ResourceConversion "textures/$relative" $dds
                # Keep the resource-loader name and the observed in-game converter name.
                Copy-Item -LiteralPath $dds -Destination (Join-Path (Split-Path $dds -Parent) "textures_$flat")
                $pctName = [IO.Path]::ChangeExtension($flat, 'pct')
                $pct = Join-Path $stage "prebuild\textures\pct\$pctName"
                Invoke-ResourceConversion "textures/$relative" $pct @('--all-pct', '--singl-thread-pct-convert')
                Copy-Item -LiteralPath $pct -Destination (Join-Path (Split-Path $pct -Parent) "textures_$pctName")
            }
        }
        $meshRoot = Join-Path $stage 'meshes'
        if (Test-Path -LiteralPath $meshRoot) {
            Get-ChildItem -LiteralPath $meshRoot -Recurse -Filter '*.fbx' | ForEach-Object {
                $relative = $_.FullName.Substring($meshRoot.Length + 1).Replace('\', '/')
                $resource = $relative.Substring(0, $relative.Length - 4)
                Invoke-ResourceConversion "meshes/$resource" (Join-Path $stage ("prebuild\meshes\" + $resource.Replace('/', '_')))
            }
        }
    }
    finally { Pop-Location }

    # Deploy only after every conversion succeeded; retain the old workspace outside Mods.
    if (Test-Path -LiteralPath $destination) {
        $backupRoot = Join-Path $SnowRunnerMedia 'ModBackups'
        New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
        $backup = Join-Path $backupRoot ($ModName + '-' + [guid]::NewGuid().ToString('N'))
        Copy-Item -LiteralPath $destination -Destination $backup -Recurse
        Write-Host "Previous workspace backed up to $backup"
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
    Copy-Item -LiteralPath $stage -Destination $destination -Recurse
    Write-Host "Converted resources deployed to $destination"
    Write-Host 'Local cache deployed. Check Mod Manager status before testing Create; in-game registration remains unverified.'
    Write-Host 'PC PCT and DDS caches only; this is not a platform release pack.'
}
finally {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
}
