param(
    [string]$OutputDir = "repo"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$outputRoot = Join-Path $repoRoot $OutputDir
$zipRoot = Join-Path $outputRoot "zips"
$skinSourceDirs = @("1080i", "colors", "extras", "fonts", "language", "media", "resources", "shortcuts")
$skinSourceFiles = @("addon.xml", "LICENSE", "README.md")
$repoAddonDir = "repository.bigdaddy-cpm"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("kodi-repo-" + [System.Guid]::NewGuid().ToString("N"))

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function New-AddonZip {
    param(
        [string]$SourcePath,
        [string]$DestinationZip
    )

    if (Test-Path $DestinationZip) {
        Remove-Item -LiteralPath $DestinationZip -Force
    }

    $sourceParent = Split-Path -Path $SourcePath -Parent
    $rootName = Split-Path -Path $SourcePath -Leaf

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $zip = [System.IO.Compression.ZipFile]::Open($DestinationZip, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $files = Get-ChildItem -LiteralPath $SourcePath -Recurse -File
        foreach ($file in $files) {
            $relativePath = $file.FullName.Substring($sourceParent.Length + 1).Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip,
                $file.FullName,
                $relativePath,
                [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    }
    finally {
        $zip.Dispose()
    }
}

try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null

    if (Test-Path $outputRoot) {
        Remove-Item -LiteralPath $outputRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path $outputRoot | Out-Null
    New-Item -ItemType Directory -Path $zipRoot | Out-Null

    [xml]$skinAddon = Get-Content -LiteralPath (Join-Path $repoRoot "addon.xml") -Raw
    [xml]$repoAddon = Get-Content -LiteralPath (Join-Path (Join-Path $repoRoot $repoAddonDir) "addon.xml") -Raw

    $skinId = $skinAddon.addon.id
    $skinVersion = $skinAddon.addon.version
    $repoId = $repoAddon.addon.id
    $repoVersion = $repoAddon.addon.version

    $skinZipDir = Join-Path $zipRoot $skinId
    $repoZipDir = Join-Path $zipRoot $repoId
    New-Item -ItemType Directory -Path $skinZipDir | Out-Null
    New-Item -ItemType Directory -Path $repoZipDir | Out-Null

    $skinStage = Join-Path $tempRoot $skinId
    $repoStage = Join-Path $tempRoot $repoId
    New-Item -ItemType Directory -Path $skinStage | Out-Null
    New-Item -ItemType Directory -Path $repoStage | Out-Null

    foreach ($dir in $skinSourceDirs) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $dir) -Destination $skinStage -Recurse
    }

    foreach ($file in $skinSourceFiles) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $file) -Destination $skinStage
    }

    Copy-Item -Path (Join-Path (Join-Path $repoRoot $repoAddonDir) "*") -Destination $repoStage -Recurse

    $skinZip = Join-Path $skinZipDir ("{0}-{1}.zip" -f $skinId, $skinVersion)
    $repoZip = Join-Path $repoZipDir ("{0}-{1}.zip" -f $repoId, $repoVersion)

    New-AddonZip -SourcePath $skinStage -DestinationZip $skinZip
    New-AddonZip -SourcePath $repoStage -DestinationZip $repoZip
    Copy-Item -LiteralPath $repoZip -Destination (Join-Path $outputRoot ([System.IO.Path]::GetFileName($repoZip)))

    $addonsXml = @(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<addons>'
        $repoAddon.addon.OuterXml
        $skinAddon.addon.OuterXml
        '</addons>'
        ''
    ) -join "`n"

    $addonsPath = Join-Path $outputRoot "addons.xml"
    $checksumPath = Join-Path $outputRoot "addons.xml.md5"

    Write-Utf8NoBom -Path $addonsPath -Content $addonsXml

    $md5 = (Get-FileHash -LiteralPath $addonsPath -Algorithm MD5).Hash.ToLowerInvariant()
    Write-Utf8NoBom -Path $checksumPath -Content ($md5 + "`n")

    Write-Host "Built Kodi repo output at: $outputRoot"
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
