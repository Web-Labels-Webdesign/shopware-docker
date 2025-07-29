# Build script for Shopware Docker images (PowerShell)
param(
    [string]$Version = "6.7"
)

$ErrorActionPreference = "Stop"

Write-Host "Building Shopware Docker image for version $Version" -ForegroundColor Green

# Determine PHP version based on Shopware version
$PhpVersion = switch ($Version) {
    "6.5" { "8.1" }
    "6.6" { "8.2" }
    "6.7" { "8.3" }
    default {
        Write-Host "Unsupported Shopware version: $Version" -ForegroundColor Red
        Write-Host "Supported versions: 6.5, 6.6, 6.7"
        exit 1
    }
}

Write-Host "Using PHP version: $PhpVersion" -ForegroundColor Yellow

# Get latest commit for the version (optional)
$Commit = ""
try {
    if (Get-Command curl -ErrorAction SilentlyContinue) {
        Write-Host "Fetching latest commit for Shopware $Version..." -ForegroundColor Yellow
        
        $tags = curl -s "https://api.github.com/repos/shopware/shopware/tags" | ConvertFrom-Json
        $versionTags = $tags | Where-Object { $_.name.StartsWith("v$Version") } | Sort-Object name -Descending
        
        if ($versionTags.Count -gt 0) {
            $latestTag = $versionTags[0].name
            $tagInfo = curl -s "https://api.github.com/repos/shopware/shopware/git/refs/tags/$latestTag" | ConvertFrom-Json
            $Commit = $tagInfo.object.sha
            Write-Host "Latest tag: $latestTag ($Commit)" -ForegroundColor Green
        } else {
            Write-Host "No specific tag found, using branch latest" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "Could not fetch latest commit info" -ForegroundColor Yellow
}

# Build command
$buildArgs = "--build-arg SHOPWARE_VERSION=$Version --build-arg PHP_VERSION=$PhpVersion"
if ($Commit) {
    $buildArgs += " --build-arg SHOPWARE_COMMIT=$Commit"
}

Write-Host "Building Docker image..." -ForegroundColor Yellow
$buildCommand = "docker build $buildArgs -t shopware-dev:$Version ."
Invoke-Expression $buildCommand

Write-Host "✅ Build completed successfully!" -ForegroundColor Green
Write-Host "Image: shopware-dev:$Version" -ForegroundColor Yellow
Write-Host ""
Write-Host "To run the container:"
Write-Host "docker run -d --name shopware-dev-$Version -p 8080:80 -p 3306:3306 shopware-dev:$Version"
Write-Host ""
Write-Host "Access URLs:"
Write-Host "  Frontend: http://localhost:8080"
Write-Host "  Admin: http://localhost:8080/admin"
Write-Host "  Default credentials: admin / shopware"
