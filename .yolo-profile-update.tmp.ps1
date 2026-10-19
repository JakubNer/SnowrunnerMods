$ps_root = Split-Path -Parent $MyInvocation.MyCommand.Path
$portableHome = Split-Path -Parent (Split-Path -Parent $ps_root)

(Get-PSProvider 'FileSystem').Home = $portableHome
Set-Variable -Force HOME $portableHome
$env:HOME = $portableHome

$scripts = Join-Path $ps_root 'Scripts'
$modules = Join-Path $ps_root 'Modules'
$docs = '~\documents'
$src = '~\src'
$kb = '~\Dropbox\kb'
$desktop = '~\desktop'
$wspcs = 'w:\wspc'
$tmp = '~\tmp'
$android = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Android\sdk'

function mklink { cmd /c mklink $args }

function jj7z { iex "& 'C:\Program Files\7-Zip\7zFM.exe' $args" }

function jjscp { iex "& 'C:\Program Files (x86)\PuTTY\pscp' $args" }

function jjsudo {
    runas /profile /user:Administrator powershell
}

function jjwhich { Get-Command $args }

function grep { $input | Out-String -Stream | Select-String $args }

function jjrefreshenv {
    Set-Location $ps_root
    refreshenv
}

function yolo {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
        [string[]] $Prompt
    )

    $ErrorActionPreference = 'Stop'
    $continueCli = Get-Command cn -ErrorAction SilentlyContinue
    if (-not $continueCli) {
        throw "Continue CLI command 'cn' is not available on PATH. Install or expose the standalone Continue CLI first."
    }

    $continueConfig = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.continue\config.yaml'
    if (-not (Test-Path -LiteralPath $continueConfig)) {
        throw "Continue configuration does not exist: $continueConfig"
    }

    $logPath = Join-Path (Get-Location).Path 'yolo.md'
    if (-not (Test-Path -LiteralPath $logPath)) {
        @(
            '# Yolo Continue session'
            ''
            "Working directory: $(Get-Location)"
            ''
        ) | Set-Content -LiteralPath $logPath -Encoding UTF8
    }

    $currentPrompt = ($Prompt -join ' ').Trim()
    $resume = $false

    while ($true) {
        if ([string]::IsNullOrWhiteSpace($currentPrompt)) {
            $currentPrompt = (Read-Host 'yolo').Trim()
        }
        if ([string]::IsNullOrWhiteSpace($currentPrompt) -or $currentPrompt -in ':exit', ':quit') {
            break
        }

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'
        @(
            "## $timestamp"
            ''
            '### Prompt'
            ''
            $currentPrompt
            ''
            '### Response'
            ''
        ) | Add-Content -LiteralPath $logPath -Encoding UTF8

        $arguments = @(
            '--config', $continueConfig
            '-p', $currentPrompt
            '--allow', '*'
            '--silent'
        )
        if ($resume) {
            $arguments += '--resume'
        }

        $response = @(& $continueCli.Source @arguments 2>&1)
        $commandExitCode = $LASTEXITCODE
        $response | ForEach-Object { Write-Host $_ }
        $response | Out-String | Add-Content -LiteralPath $logPath -Encoding UTF8
        Add-Content -LiteralPath $logPath -Value "`n---`n" -Encoding UTF8

        if ($commandExitCode -ne 0) {
            Write-Error "Continue CLI exited with code $commandExitCode. See $logPath"
        }

        $resume = $true
        $currentPrompt = ''
    }

    Write-Host "Session transcript: $logPath"
}

if (($env:Path -split ';') -notcontains $scripts) {
    $env:Path += ";$scripts"
}

$ErrorActionPreference = 'SilentlyContinue'

Set-ItemProperty 'HKCU::\Software\Microsoft\Windows\CurrentVersion\Explorer' 'DisplayToastAtBottom' '0'
