[cmdletbinding()]
param()

try{
    Remove-Module pecan-waffle-visualstudio -Force -ErrorAction SilentlyContinue
}
catch{
    # do nothing
}

function Get-SolutionDirPath{
    [cmdletbinding()]
    param()
    process{
        $result = $destPath
        if(-not [string]::IsNullOrWhiteSpace($solutionRoot)){
            $result = $solutionRoot
        }

        # return the result
        $result
    }
}

function Update-PWArtifactsPath{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo[]]$filesToUpdate,

        [Parameter(Position=1,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo]$solutionRoot
    )
    process{
        if(-not (Test-Path $solutionRoot)){
            throw ('Did not find solution root at [{0}]' -f $solutionRoot)
        }

        $slnpath = $solutionRoot.FullName.TrimEnd('\')
        foreach($file in $filesToUpdate){
            if(-not (Test-Path $file)){
                throw ('Did not find project file at [{0}]' -f $file)
            }

            [string[]]$artifactsStrings = InternalGet-ArtifactsStringsFromFile -files $file
            # define replacements for each
            if( ($artifactsStrings -ne $null) -and ($artifactsStrings.Length -gt 0) ){
                # calculate the rel path to the solution and get packages path based on that
                $projDir = (Split-Path $file.FullName -Parent)
                $relArtsDir = (InternalGet-RelativePath -fromPath $projDir -toPath $slnpath)
                $newArtStr = '{0}packages' -f $relArtsDir
                $replacements = @{}
                foreach($artStr in $artifactsStrings){
                    $replacements[$artStr]=$newArtStr
                }

                Replace-TextInFolder -folder $projDir -include $file.Name -replacements $replacements
            }
        }
    }
}

function Update-PWArtifactsPathInProjectFiles{
    [cmdletbinding()]
    param(
        [Parameter(Position=0)]
        [string]$slnRoot = (Get-SolutionDirPath),

        [Parameter(Position=1)]
        [string]$filePattern = '*.xproj'
    )
    process{
        if(-not ([string]::IsNullOrWhiteSpace($slnRoot))){
            $projFiles = (Get-ChildItem -Path $slnRoot $filePattern -Recurse -File).FullName
            if( ($projFiles -ne $null) -and ($projFiles.Length -gt 0)){
                Update-PWArtifactsPath -filesToUpdate $projFiles -solutionRoot $slnRoot
            }
        }
    }
}

<#
.SYNOPSIS
    This will update the packages path in the given dir for the file pattern. The most common usage of this
    is to update the HintPath for NuGet packages in .csproj/.vbproj files.
#>
# TODO: Shoud this be updated to work with custom nuget pkg path?
#       https://github.com/ligershark/template-builder/blob/e801f5ef53a18739a3fb11b0c9b22d1e57bc00b5/src/TemplateBuilder/FixNuGetPackageHintPathsWizard.cs#L184
function Update-PWPackagesPath{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo[]]$filesToUpdate,

        [Parameter(Position=1,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo]$solutionRoot
    )
    process{
        if(-not (Test-Path $solutionRoot)){
            throw ('Did not find solution root at [{0}]' -f $solutionRoot)
        }

        $slnpath = $solutionRoot.FullName.TrimEnd('\')
        foreach($file in $filesToUpdate){
            if(-not (Test-Path $file)){
                throw ('Did not find project file at [{0}]' -f $file)
            }

            # get pkgs string from this file
            [string[]]$pkgsString = InternalGet-PackageStringsFromFile -files $file
            # define replacements for each
            if( ($pkgsString -ne $null) -and ($pkgsString.Length -gt 0) ){
                # calculate the rel path to the solution and get packages path based on that
                $projDir = (Split-Path $file.FullName -Parent)
                $relPkgsDir = (InternalGet-RelativePath -fromPath $projDir -toPath $slnpath)
                $newPkgsStr = '{0}packages' -f $relPkgsDir
                $replacements = @{}
                foreach($pkgStr in $pkgsString){
                    $replacements[$pkgStr]=$newPkgsStr
                }

                Replace-TextInFolder -folder $projDir -include $file.Name -replacements $replacements
            }
        }
    }
}

function Update-PWPackagesPathInProjectFiles{
    [cmdletbinding()]
    param(
        [Parameter(Position=0)]
        [string]$slnRoot = (Get-SolutionDirPath),

        [Parameter(Position=1)]
        [string]$filePattern = '*.*proj'
    )
    process{
        if(-not ([string]::IsNullOrWhiteSpace($slnRoot))){
            $projFiles = (Get-ChildItem -Path $slnRoot $filePattern -Recurse -File).FullName
            if( ($projFiles -ne $null) -and ($projFiles.Length -gt 0)){
                Update-PWPackagesPath -filesToUpdate $projFiles -solutionRoot $slnRoot
            }
        }
    }
}

function InternalGet-RelativePath{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$fromPath,

        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$toPath
    )
    process{
        $fromPathToUse = (Resolve-Path $fromPath).Path
        if( (Get-Item $fromPathToUse) -is [System.IO.DirectoryInfo]){
            $fromPathToUse += [System.IO.Path]::DirectorySeparatorChar
        }

        $toPathToUse = (Resolve-Path $toPath).Path
        if( (Get-Item $toPathToUse) -is [System.IO.DirectoryInfo]){
            $toPathToUse += [System.IO.Path]::DirectorySeparatorChar
        }

        [uri]$fromUri = New-Object -TypeName 'uri' -ArgumentList $fromPathToUse
        [uri]$toUri = New-Object -TypeName 'uri' -ArgumentList $toPathToUse

        [string]$relPath = $toPath
        # if the Scheme doesn't match just return toPath
        if($fromUri.Scheme -eq $toUri.Scheme){
            [uri]$relUri = $fromUri.MakeRelativeUri($toUri)
            $relPath = [Uri]::UnescapeDataString($relUri.ToString())

            if([string]::Equals($toUri.Scheme, [Uri]::UriSchemeFile, [System.StringComparison]::OrdinalIgnoreCase)){
                $relPath = $relPath.Replace([System.IO.Path]::AltDirectorySeparatorChar,[System.IO.Path]::DirectorySeparatorChar)
            }
        }

        if([string]::IsNullOrWhiteSpace($relPath)){
            $relPath = ('.{0}' -f [System.IO.Path]::DirectorySeparatorChar)
        }

        #'relpath:[{0}]' -f $relPath | Write-verbose

        # return the result here
        $relPath
    }
}


function InternalGet-MatchingStringsFromFile{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true)]
        [System.IO.FileInfo[]]$files,

        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $pattern
    )
    process{
        foreach($filePath in $files){
            if(-not (Test-Path $filePath.FullName)){
                throw ('File not found at [{0}]' -f $filePath.FullName)
            }

            Get-Content $filePath.FullName | select-string $pattern | % {
                $match = [regex]::Match($_,$pattern)
                if($match.Success -and ($match.Groups.Count -ge 1) -and ($match.Groups[0] -ne $null)){
                    $match.Groups[0].Value
                }
            } | Select-Object -Unique
        }
    }
}

function InternalGet-PackageStringsFromFile{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true)]
        [System.IO.FileInfo[]]$files
    )
    process{
        InternalGet-MatchingStringsFromFile -files $files -pattern '[\.\\/]+packages'
    }
}

function InternalGet-ArtifactsStringsFromFile{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true)]
        [System.IO.FileInfo[]]$files
    )
    process{
        InternalGet-MatchingStringsFromFile -files $files -pattern '[\.\\/]+artifacts'
    }
}

Export-ModuleMember -function * -Alias *