# dblm Installer for Windows
# Usage: irm https://raw.githubusercontent.com/prasenjeet-symon/dblm-releases/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$releasesRepo = "prasenjeet-symon/dblm-releases"
$installDir = "$env:LOCALAPPDATA\dblm"

# Detect architecture
$arch = switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64" { "x86_64" }
    "ARM64" { "arm64" }
    default {
        Write-Host "Unsupported architecture: $env:PROCESSOR_ARCHITECTURE" -ForegroundColor Red
        exit 1
    }
}

# Fetch latest release
Write-Host "Fetching latest release..." -ForegroundColor Cyan
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$releasesRepo/releases/latest"
$tag = $release.tag_name
$versionNoV = $tag -replace "^v"

$assetName = "dblm_${versionNoV}_windows_${arch}.zip"
$asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
if (-not $asset) {
    Write-Host "Could not find release asset: $assetName" -ForegroundColor Red
    exit 1
}

$zipPath = "$env:TEMP\dblm.zip"

# Download
Write-Host "Downloading dblm $tag for Windows/$arch..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing

# Extract
if (Test-Path $installDir) {
    Remove-Item $installDir -Recurse -Force
}
New-Item -ItemType Directory -Path $installDir -Force | Out-Null

Write-Host "Extracting to $installDir..." -ForegroundColor Cyan
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
Remove-Item $zipPath

# Add to PATH if not already present
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$installDir*") {
    Write-Host "Adding $installDir to PATH..." -ForegroundColor Cyan
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$installDir", "User")
    Write-Host "Open a new terminal window for PATH changes to take effect." -ForegroundColor Yellow
}

# Verify
$binaryPath = "$installDir\dblm.exe"
$version = & $binaryPath version 2>$null
Write-Host ""
Write-Host "dblm $version installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  dblm connect add     # add a database connection" -ForegroundColor White
Write-Host "  dblm index add <db>  # index the schema" -ForegroundColor White
Write-Host "  dblm query <db>      # ask questions in natural language" -ForegroundColor White
