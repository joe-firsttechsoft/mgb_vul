<#
.SYNOPSIS
Builds a source-only copy of the MGB FEP project for vulnerability scanning.

.DESCRIPTION
Copies $HOME/Repo/idea_clone/mgbfep/source/fep to a local output folder,
skipping directories listed in the MGB .gitignore files. Files under src/test are
removed unless their file name contains BatchTaskUtil, generator, or RemoveVersion.
The fep-suipConnect and fep-bpm folders are also excluded.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SourceRoot,
    [string]$DestinationRoot,
    [string[]]$GitIgnoreFiles,
    [string[]]$ExtraExcludedDirectories = @("fep-suipConnect", "fep-bpm"),
    [string[]]$KeepTestNameParts = @("BatchTaskUtil", "generator", "RemoveVersion")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 來源 repo 根目錄，修改此變數即可調整所有相關路徑
$MgbFepRepo = "$HOME/Repo/idea_clone/mgbfep"

if (-not $SourceRoot)     { $SourceRoot     = "$MgbFepRepo/source/fep" }
if (-not $DestinationRoot){ $DestinationRoot = Join-Path $PSScriptRoot "output/fep" }
if (-not $GitIgnoreFiles) { $GitIgnoreFiles  = @("$MgbFepRepo/.gitignore", "$MgbFepRepo/source/.gitignore") }

function Convert-ToUnixPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return ($Path -replace "\\", "/").TrimEnd("/")
}

function Get-RelativeUnixPath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$FullPath
    )

    $base = Convert-ToUnixPath -Path ([System.IO.Path]::GetFullPath($BasePath))
    $full = Convert-ToUnixPath -Path ([System.IO.Path]::GetFullPath($FullPath))

    if ($full.Equals($base, [System.StringComparison]::OrdinalIgnoreCase)) {
        return ""
    }

    if (-not $full.StartsWith("$base/", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path '$FullPath' is not under '$BasePath'."
    }

    return $full.Substring($base.Length + 1)
}

function Test-IsUnderPath {
    param(
        [Parameter(Mandatory = $true)][string]$ParentPath,
        [Parameter(Mandatory = $true)][string]$ChildPath
    )

    $parent = Convert-ToUnixPath -Path ([System.IO.Path]::GetFullPath($ParentPath))
    $child = Convert-ToUnixPath -Path ([System.IO.Path]::GetFullPath($ChildPath))

    return $child.Equals($parent, [System.StringComparison]::OrdinalIgnoreCase) -or
        $child.StartsWith("$parent/", [System.StringComparison]::OrdinalIgnoreCase)
}

function Convert-GitIgnoreDirectoryPatterns {
    param(
        [Parameter(Mandatory = $true)][string[]]$Files
    )

    $patterns = New-Object System.Collections.Generic.List[string]

    foreach ($file in $Files) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            Write-Warning "Gitignore file not found: $file"
            continue
        }

        foreach ($rawLine in Get-Content -LiteralPath $file) {
            $line = $rawLine.Trim()

            if ($line.Length -eq 0 -or $line.StartsWith("#") -or $line.StartsWith("!")) {
                continue
            }

            $pattern = $line.TrimEnd("/")
            if ($pattern.Length -eq 0) {
                continue
            }

            if ($pattern.StartsWith("/source/fep/")) {
                $pattern = $pattern.Substring("/source/fep/".Length)
            }
            elseif ($pattern.StartsWith("source/fep/")) {
                $pattern = $pattern.Substring("source/fep/".Length)
            }
            elseif ($pattern.StartsWith("/fep/")) {
                $pattern = $pattern.Substring("/fep/".Length)
            }
            elseif ($pattern.StartsWith("fep/")) {
                $pattern = $pattern.Substring("fep/".Length)
            }
            elseif ($pattern -eq "/fep" -or $pattern -eq "fep") {
                continue
            }
            elseif ($pattern.StartsWith("/")) {
                $pattern = $pattern.TrimStart("/")
            }

            if ($pattern.Length -eq 0) {
                continue
            }

            $patterns.Add((Convert-ToUnixPath -Path $pattern))
        }
    }

    $patterns.Add(".git")

    return $patterns |
        Sort-Object -Unique |
        Where-Object { $_ -notmatch "\.[A-Za-z0-9]+$" -or $_ -like ".*" }
}

function Test-MatchesGitIgnoreDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string[]]$Patterns
    )

    $relative = Convert-ToUnixPath -Path $RelativePath
    $segments = $relative -split "/"

    foreach ($pattern in $Patterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) {
            continue
        }

        if ($pattern.Contains("/")) {
            if ($relative.Equals($pattern, [System.StringComparison]::OrdinalIgnoreCase) -or
                $relative.StartsWith("$pattern/", [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
        elseif ($segments -contains $pattern) {
            return $true
        }
        elseif ($pattern.Contains("*") -and ($relative -like $pattern -or $relative -like "*/$pattern/*")) {
            return $true
        }
    }

    return $false
}

function Test-KeepTestFile {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string[]]$KeepNameParts
    )

    foreach ($part in $KeepNameParts) {
        if ($FileName.IndexOf($part, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $true
        }
    }

    return $false
}

function Remove-EmptyDirectories {
    param([Parameter(Mandatory = $true)][string]$Root)

    Get-ChildItem -LiteralPath $Root -Directory -Recurse -Force |
        Sort-Object FullName -Descending |
        ForEach-Object {
            if (-not (Get-ChildItem -LiteralPath $_.FullName -Force | Select-Object -First 1)) {
                Remove-Item -LiteralPath $_.FullName -Force
            }
        }
}

if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot does not exist or is not a directory: $SourceRoot"
}

$resolvedSourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
$resolvedDestinationRoot = [System.IO.Path]::GetFullPath($DestinationRoot)

if (Test-IsUnderPath -ParentPath $resolvedSourceRoot -ChildPath $resolvedDestinationRoot) {
    throw "DestinationRoot cannot be inside SourceRoot: $resolvedDestinationRoot"
}

if (-not (Test-IsUnderPath -ParentPath $PSScriptRoot -ChildPath $resolvedDestinationRoot)) {
    throw "DestinationRoot must be under the script directory '$PSScriptRoot': $resolvedDestinationRoot"
}

$ignoreDirectoryPatterns = @(Convert-GitIgnoreDirectoryPatterns -Files $GitIgnoreFiles)
$ignoreDirectoryPatterns += $ExtraExcludedDirectories
$ignoreDirectoryPatterns = @($ignoreDirectoryPatterns | Sort-Object -Unique)

$script:copiedCount = 0
$script:skippedIgnoredCount = 0
$script:skippedTestCount = 0

if (Test-Path -LiteralPath $resolvedDestinationRoot) {
    if ($PSCmdlet.ShouldProcess($resolvedDestinationRoot, "Remove existing destination")) {
        Remove-Item -LiteralPath $resolvedDestinationRoot -Recurse -Force
    }
}

if ($PSCmdlet.ShouldProcess($resolvedDestinationRoot, "Create destination")) {
    New-Item -ItemType Directory -Path $resolvedDestinationRoot -Force | Out-Null
}

Get-ChildItem -LiteralPath $resolvedSourceRoot -File -Recurse -Force | ForEach-Object {
    $relativePath = Get-RelativeUnixPath -BasePath $resolvedSourceRoot -FullPath $_.FullName
    $relativeDirectory = [System.IO.Path]::GetDirectoryName($relativePath)

    if ([string]::IsNullOrEmpty($relativeDirectory)) {
        $relativeDirectory = "."
    }
    else {
        $relativeDirectory = Convert-ToUnixPath -Path $relativeDirectory
    }

    if ($relativeDirectory -ne "." -and
        (Test-MatchesGitIgnoreDirectory -RelativePath $relativeDirectory -Patterns $ignoreDirectoryPatterns)) {
        $script:skippedIgnoredCount++
        return
    }

    if ($relativePath -match "(^|/)src/test/" -and
        -not (Test-KeepTestFile -FileName $_.Name -KeepNameParts $KeepTestNameParts)) {
        $script:skippedTestCount++
        return
    }

    $destinationPath = Join-Path $resolvedDestinationRoot ($relativePath -replace "/", [System.IO.Path]::DirectorySeparatorChar)
    $destinationDirectory = [System.IO.Path]::GetDirectoryName($destinationPath)

    if ($PSCmdlet.ShouldProcess($destinationPath, "Copy source file")) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $destinationPath -Force
    }

    $script:copiedCount++
}

if (Test-Path -LiteralPath $resolvedDestinationRoot) {
    Remove-EmptyDirectories -Root $resolvedDestinationRoot
}

Write-Host "Source: $resolvedSourceRoot"
Write-Host "Destination: $resolvedDestinationRoot"
Write-Host "Copied files: $script:copiedCount"
Write-Host "Skipped by gitignore directories: $script:skippedIgnoredCount"
Write-Host "Skipped src/test files: $script:skippedTestCount"
Write-Host "Kept src/test file name parts: $($KeepTestNameParts -join ', ')"
