[cmdletbinding()]
param()

try{
    Remove-Module pecan-waffle-visualstudio -Force -ErrorAction SilentlyContinue | Out-Null
}
catch{
    # do nothing
}

$scriptDir = split-path -parent $MyInvocation.MyCommand.Definition

# all types here must be strings
$global:pwvssettings = New-Object -TypeName psobject -Property @{
    TempDir = ([System.IO.DirectoryInfo]('{0}\pecan-waffle\temp\vs01' -f $env:LOCALAPPDATA)).FullName
    VsTemplateTempFilePath = ([System.IO.DirectoryInfo]('{0}\pecan-waffle\temp\vs01\t.zip' -f $env:LOCALAPPDATA)).FullName
    VsTemplateSourceDir = [string](join-path $scriptDir 'vs-template-zip')
    
}
$global:pwvssettings.VsTemplateTempFilePath = (Join-Path $global:pwvssettings.TempDir 'template01\vstemplate.zip')

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

function Update-VisualStuidoProjects{
    [cmdletbinding()]
    param(
        [Parameter(Position=0)]
        [Alias("slnRoot")]
        [System.IO.DirectoryInfo]$solutionRoot
    )
    process{
        Update-PWPackagesPathInProjectFiles -slnRoot $SolutionRoot
        Update-PWArtifactsPathInProjectFiles -slnRoot $SolutionRoot
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
                $newArtStr = '{0}artifacts' -f $relArtsDir
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
$global:pwvstemplateindex = 0

function New-VsTemplateZipFile{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$vsTemplateFilePath,
        
        [Parameter(Position=1)]
        [ValidateNotNullOrEmpty()]
        [string]$outputDirectory
    )
    process{
        if(-not (Test-Path $outputDirectory)){
            throw ('output directory not found at [{0}]' -f $outputDirectory)
        }

        # create a .zip file for the .vstemplate file and add it to the .zip
        $filename = ('VsTemplateProj{0}.project.zip' -f (++$global:pwvstemplateindex))      

        $ziptempfile = (InternalNew-VsTemplateZip -vstemplateFilePath $vsTemplateFilePath)
        Move-Item $ziptempfile (Join-Path $outputDirectory $filename) -Force
    }
}

function Copy-TemplatesTo{
    [cmdletbinding()]
    param(
        [Parameter(Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({test-path $_ -PathType Leaf})]
        [string]$templateFilePath,

        [Parameter(Position=1)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({test-path $_ -PathType Container})]
        [string]$outputDirectry
    )
    process{
        # clear templates
        Clear-PWTemplates
        Add-PWTemplateSource -path (Split-Path $templateFilePath -Parent)

        $projTemplates = ($Global:pecanwafflesettings.Templates|Where-Object {$_.Type -eq 'ProjectTemplate'})
        foreach($pt in $projTemplates){
            'Adding template [{0}] to vsix [{1}]' -f $pt.Name,$vsixFilePath | Write-Verbose
            $templateName = $pt.Name

            $destDir = (Join-Path $outputDirectry $templateName)
            if( (Test-Path $destDir)){
                Remove-Item -Path $destDir -Recurse | Write-Verbose
            }

            Ensure-DirectoryExists -path $destDir | Write-Verbose

            Copy-TemplateSourceFiles -template $pt -destFolderPath $destDir
        }
    }
}

function InternalGet-TemplateVsTemplateZipFile{
    [cmdletbinding()]
    param(
        [Parameter(Position=0)]
        [string]$templatefilepath = ($global:pwvssettings.VsTemplateTempFilePath),
        [Parameter(Position=1)]
        [string]$templateSourceFolder = ($global:pwvssettings.VsTemplateSourceDir)
    )
    process{
        if([string]::IsNullOrWhiteSpace($templateSourceFolder)){
            $templateSourceFolder = ($global:pwvssettings.VsTemplateSourceDir)
        }
        # if the file exists return it
        if(-not (Test-Path $templatefilepath)){
            # create a .zip file from the source folder
            $templateFileDir = (Split-Path $templatefilepath -Parent)
            Ensure-DirectoryExists -path $templateFileDir | Out-Null
            $zipitems = (Get-ChildItem -Path $templateSourceFolder -Recurse -File)
            InternalNew-ZipFile -ZipFilePath $templatefilepath -rootFolder $templateSourceFolder -InputObject $zipitems.FullName | Out-Null
        }

        # copy it to a temp dir
        $tempdir = Get-NewTempDir
        $temppath = ([System.IO.FileInfo](Join-Path (Get-NewTempDir) (Split-Path $templatefilepath -Leaf))).FullName
        Copy-Item (([System.IO.FileInfo]$templatefilepath).FullName) -Destination $temppath
        # return the path to the caller
        $temppath
    }
}

function InternalNew-VsTemplateZip{
    [cmdletbinding()]
    param(
        [Parameter(Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$destpath,

        [Parameter(Position=1)]
        [string]$vstemplateFilePath,

        [Parameter(Position=2)]
        [string]$templateZipPath
    )
    process{
        if([string]::IsNullOrEmpty($templateZipPath)){
            $templateZipPath = (InternalGet-TemplateVsTemplateZipFile)
        }
        
        # copy to temp dir

        # copy zip file to temp
        $tempdir = Get-NewTempDir

        $newtempfilepath = (Join-Path (Get-NewTempDir) 'vstemplate.zip')
        
        if( (-not ([string]::IsNullOrWhiteSpace($destpath))) -and (test-path $destpath) ){
            Remove-Item $destpath | Write-Verbose
        }

        if(-not ([string]::IsNullOrWhiteSpace($templateZipPath)) -and (Test-Path $vstemplateFilePath)){
            # add the .vstemplate file to the .zip
            InternalNew-ZipFile -ZipFilePath $templateZipPath -InputObject $vstemplateFilePath -rootFolder (([System.IO.FileInfo]$vstemplateFilePath).Directory.FullName) -Append | Out-Null
        }

        if(-not ([string]::IsNullOrWhiteSpace($destpath))){
            $parentdir = (Split-Path $destpath -Parent)
            if(-not (Test-Path $parentdir)){
                New-Item -Path $parentdir -ItemType Directory | Write-Verbose
            }

            Copy-Item $templateZipPath $destpath | Write-Verbose

            if( -not ([string]::IsNullOrWhiteSpace($tempdir)) -and (Test-Path $tempdir)){
                Remove-Item -Path $tempdir -Recurse | Write-Verbose
            }

            # return original path to caller
            $destpath
        }
        else{
            # return the path to the caller
            $templateZipPath
        }
    }
}

# Modified from: http://ss64.com/ps/zip.html / http://ss64.com/ps/zip.txt
Add-Type -As System.IO.Compression.FileSystem
function InternalNew-ZipFile {
	#.Synopsis
	#  Create a new zip file, optionally appending to an existing zip...
	[CmdletBinding()]
	param(
		# The path of the zip to create
		[Parameter(Position=0, Mandatory=$true)]
		$ZipFilePath,
 
		# Items that we want to add to the ZipFile
		[Parameter(Position=1, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
		[Alias("PSPath","Item")]
		[string[]]$InputObject = $Pwd,
 
        [string]$rootFolder = $pwd,

        [string]$relpathinzip,

		# Append to an existing zip file, instead of overwriting it
		[Switch]$Append,
 
		# The compression level (defaults to Optimal):
		#   Optimal - The compression operation should be optimally compressed, even if the operation takes a longer time to complete.
		#   Fastest - The compression operation should complete as quickly as possible, even if the resulting file is not optimally compressed.
		#   NoCompression - No compression should be performed on the file.
		[System.IO.Compression.CompressionLevel]$Compression = "Optimal"
	)
	begin {
		# Make sure the folder already exists
		[string]$File = Split-Path $ZipFilePath -Leaf
		[string]$Folder = $(if($Folder = Split-Path $ZipFilePath) { Resolve-Path $Folder } else { $Pwd })
		$ZipFilePath = Join-Path $Folder $File
		# If they don't want to append, make sure the zip file doesn't already exist.
		if(!$Append) {
			if(Test-Path $ZipFilePath) { Remove-Item $ZipFilePath }
		}
		$Archive = [System.IO.Compression.ZipFile]::Open( $ZipFilePath, "Update" )
	}
	process {
		foreach($path in $InputObject) {
			foreach($item in Resolve-Path $path) {
				# Push-Location so we can use Resolve-Path -Relative
				# This will get the file, or all the files in the folder (recursively)
				foreach($file in Get-ChildItem $item -Recurse -File -Force | % FullName) {
					# Calculate the relative file path
                    $relative = InternalGet-RelativePath -fromPath $rootFolder -toPath $file
                    if(-not [string]::IsNullOrWhiteSpace($relpathinzip)){
                        $relative = $relpathinzip.TrimEnd('\').TrimEnd('/') + '\' + $relative.TrimEnd('\').TrimEnd('/') + '\'
                    }

					# Add the file to the zip
					$null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive, $file, $relative, $Compression)
				}
			}
		}
	}
	end {
		$Archive.Dispose()
		Get-Item $ZipFilePath
	}
}

# items related to updating things like packages/artifacts/etc
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

function Get-7zipExe{
    [cmdletbinding()]
    param(
        [Parameter(Position=0)]
        [string]$packageName='7Zip.Sfx',

        [Parameter(Position=1)]
        [string]$packageVersion='1.0.1'
    )
    begin{
        InternalImport-NuGetPowershell2
    }
    process{
        $pkgpath = (Get-NuGetPackage -name $packageName -version $packageVersion -binpath)
        $exepath = (join-path $pkgpath '7za.exe')
        if(-not (Test-Path $exepath)){
            throw ('Did not find 7za.exe at [{0}]' -f $exepath)
        }

        $exepath
    }
}

function InternalGet-PackageStringsFromFile{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true)]
        [System.IO.FileInfo[]]$files
    )
    process{
        InternalGet-MatchingStringsFromFile -files $files -pattern '[\.|\\|/]+[\\/]packages'
    }
}

function InternalGet-ArtifactsStringsFromFile{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true)]
        [System.IO.FileInfo[]]$files
    )
    process{
        InternalGet-MatchingStringsFromFile -files $files -pattern '[\.\\/a-zA-Z0-9]+artifacts'
    }
}

# TODO: Remove this when sharing is figured out
function InternalImport-NuGetPowershell2{
    [cmdletbinding()]
    param(
        $nugetPsMinModVersion = '0.2.1.1'
    )
    process{
        # see if nuget-powershell is available and load if not
        $nugetpsloaded = $false
        if((get-command Get-NuGetPackage -ErrorAction SilentlyContinue)){
            # check the module to ensure we have the correct version

            $currentversion = (Get-Module -Name nuget-powershell).Version
            if( ($currentversion -ne $null) -and ($currentversion.CompareTo([version]::Parse($nugetPsMinModVersion)) -ge 0 )){
                $nugetpsloaded = $true
            }
        }

        if(!$nugetpsloaded){
            (new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/ligershark/nuget-powershell/master/get-nugetps.ps1") | iex
        }

        # check to see that it was loaded
        if((get-command Get-NuGetPackage -ErrorAction SilentlyContinue)){
            $nugetpsloaded = $true
        }

        if(-not $nugetpsloaded){
            throw ('Unable to load nuget-powershell, unknown error')
        }
    }
}

Export-ModuleMember -function * -Alias *