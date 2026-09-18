[CmdletBinding()]
param(
    [switch]$ConfigureWezTerm,
    [switch]$Star
)

$ErrorActionPreference = 'Stop'
$repo = 'hwei/herdr-fast-paste'
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\herdr-fast-paste'
$moduleDir = Join-Path $env:USERPROFILE '.wezterm'
$configPath = Join-Path $env:USERPROFILE '.wezterm.lua'
$archiveName = 'herdr-fast-paste-windows-x86_64.zip'
$baseUrl = "https://github.com/$repo/releases/latest/download"
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("herdr-fast-paste-" + [guid]::NewGuid())

try {
    New-Item -ItemType Directory -Force -Path $tempDir, $installDir, $moduleDir | Out-Null
    $archive = Join-Path $tempDir $archiveName
    $checksum = "$archive.sha256"
    Invoke-WebRequest -UseBasicParsing "$baseUrl/$archiveName" -OutFile $archive
    Invoke-WebRequest -UseBasicParsing "$baseUrl/$archiveName.sha256" -OutFile $checksum

    $expected = ((Get-Content -LiteralPath $checksum -Raw).Trim() -split '\s+')[0].ToLowerInvariant()
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()
    if ($actual -ne $expected) { throw "SHA256 mismatch: expected $expected, got $actual" }

    Expand-Archive -LiteralPath $archive -DestinationPath $tempDir -Force
    Copy-Item -LiteralPath (Join-Path $tempDir 'herdr-fast-paste.exe') -Destination $installDir -Force
    Copy-Item -LiteralPath (Join-Path $tempDir 'herdr_fast_paste.lua') -Destination $moduleDir -Force

    if ($ConfigureWezTerm) {
        $applyLine = "require('herdr_fast_paste').apply_to_config(config)"
        if (Test-Path -LiteralPath $configPath) {
            $content = Get-Content -LiteralPath $configPath -Raw
            if ($content -notmatch [regex]::Escape($applyLine)) {
                if ($content -notmatch '(?m)^return\s+config\s*$') {
                    throw "Cannot safely patch $configPath because it has no standalone 'return config' line."
                }
                $backup = "$configPath.herdr-fast-paste.$(Get-Date -Format yyyyMMddHHmmss).bak"
                Copy-Item -LiteralPath $configPath -Destination $backup
                $returnPattern = [regex]::new('(?m)^return\s+config\s*$')
                $content = $returnPattern.Replace($content, "$applyLine`r`n`r`nreturn config", 1)
                Set-Content -LiteralPath $configPath -Value $content -NoNewline
                Write-Host "Configured WezTerm (backup: $backup)"
            }
        } else {
            Set-Content -LiteralPath $configPath -Value "local wezterm = require 'wezterm'`r`nlocal config = wezterm.config_builder()`r`n$applyLine`r`nreturn config`r`n"
            Write-Host "Created $configPath"
        }
    }

    & (Join-Path $installDir 'herdr-fast-paste.exe') --check
    Write-Host "Installed to $installDir"
    if (-not $ConfigureWezTerm) {
        Write-Host "Run install.ps1 again with -ConfigureWezTerm, or follow the README to configure WezTerm."
    }
    if ($Star) {
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            & gh repo star $repo
            if ($LASTEXITCODE -ne 0) { throw "GitHub CLI could not star $repo" }
            Write-Host "Starred https://github.com/$repo"
        } else {
            Write-Warning "The -Star option requires an authenticated GitHub CLI (`gh`)."
        }
    }
}
finally {
    if (Test-Path -LiteralPath $tempDir) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force
    }
}
