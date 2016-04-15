[cmdletbinding()]
param()

try{
    Remove-Module pecan-waffle-visualstudio -Force -ErrorAction SilentlyContinue
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
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNull()]
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

# Items related to creating a VS template .zip file

function Add-TemplateToVsix{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$vsixFilePath,

        [Parameter(Position=1,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$templateFilePath,

        [Parameter(Position=2,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$templateName,

        [Parameter(Position=3)]
        [string]$relativePathInVsix = ('.\')
    )
    process{
        if(-not (Test-Path $vsixFilePath -PathType Leaf)){
            throw ('vsix file not found at [{0}' -f $vsixFilePath)
        }
        if(-not (Test-Path $templateFilePath -PathType Leaf)){
            throw ('template file not found at [{0}' -f $templateFilePath)
        }

        # clear templates
        Clear-PWTemplates
        Add-PWTemplateSource -path (Split-Path $templateFilePath -Parent)

        $template = ($Global:pecanwafflesettings.Templates|Where-Object {$_.Type -eq 'ProjectTemplate' -and $_.Name -eq $templateName}|Select-Object -First 1)

        if($template -eq $null){
            throw ('Template [{0}] not found' -f $templateName)
        }

        $tempdir = Get-NewTempDir
        try{
            Copy-TemplateSourceFiles -template $template -destFolderPath $tempdir
            $relpath = $relativePathInVsix.TrimEnd('\') + '\'
            InternalAdd-FolderToOpcPackage -pkgPath $vsixFilePath -folderToAdd $tempdir -relpathtofolderinopc $relpath
            <#
            $folderstoadd = (Get-ChildItem $tempdir -Directory).FullName
            foreach($folder in $folderstoadd){
                'Adding folder at [{0}] to opc package at [{1}]' -f $folder,$vsixFilePath | Write-Verbose
                $relpath = $relativePathInVsix.TrimEnd('\') + '\' + ((Get-Item $folder).Name) + '\'
                InternalAdd-FolderToOpcPackage -pkgPath $vsixFilePath -folderToAdd $folder -relpathtofolderinopc $relpath
            } 
            #>
        }
        catch{
            if( -not ([string]::IsNullOrWhiteSpace($tempdir)) -and (Test-Path $tempdir)){
                Remove-Item -Path $tempdir -Recurse | Write-Verbose
            }
        }
    }
}

function InternalAdd-FolderToOpcPackage{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$pkgPath,

        [Parameter(Position=1,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({test-path $_})]
        [string]$folderToAdd,

        [Parameter(Position=2)]
        [string]$relpathtofolderinopc = ('.\')
    )
    begin{
        [System.Reflection.Assembly]::Load("WindowsBase,Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35")
    }
    process{
        try{
            $zipPkg = [System.IO.Packaging.ZipPackage]::Open($pkgpath,[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite)
            'Updating zip package [{0}]' -f $pkgPath | Write-Verbose
            $files = (Get-ChildItem -Path $folderToAdd -Recurse -File)
            foreach($file in $files){
                'adding file [{0}]' -f $file.FullName | Write-Verbose
                $relpath = InternalGet-RelativePath -fromPath $folderToAdd -toPath $file.FullName
                $destFilename = $relpathtofolderinopc + $relpath

                [System.Uri]$uri = [System.IO.Packaging.PackUriHelper]::CreatePartUri( (new-object System.Uri($destFilename,[System.UriKind]::Relative)) )
                if($zipPkg.PartExists($uri)){
                    $zipPkg.DeletePart($uri)
                }

                $pkgPart = $zipPkg.CreatePart($uri,'',[System.IO.Packaging.CompressionOption]::Normal)
                try{
                    $fstream = New-Object System.IO.FileStream($file.FullName,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read)
                    $dest = $pkgPart.GetStream()
                    InternalCopy-Stream -inputStream $fstream -outputStream $dest
                }
                finally{
                    if($fstream -ne $null){
                        $fstream.Dispose()
                        $fstream = $null
                    }
                    if($dest -ne $null){
                        $dest.Dispose()
                        $dest = $null
                    }
                }

            }
        }
        catch{
            throw $_.exception
        }
        finally{
            if($zipPkg -ne $null){
                $zipPkg.Dispose()
                $zipPkg = $null
            }
        }        
    }
}

function InternalCopy-Stream{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNull()]
        [System.IO.Stream]$inputStream,

        [Parameter(Position=1,Mandatory=$true)]
        [ValidateNotNull()]
        [System.IO.Stream]$outputStream,

        [Parameter(Position=2)]
        [long]$bufferSize = 4096
    )
    process{
        if($inputStream.Length -le $bufferSize){
            $bufferSize = $inputStream.Length
        }

        $buffer = New-Object byte[] $bufferSize
        [int]$bytesRead = 0
        [long]$bytesWritten = 0
        while( $bytesRead = $inputStream.Read($buffer,0,$buffer.Length)){
            $outputStream.Write($buffer,0,$bytesRead)
            $bytesWritten += $bufferSize
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
            InternalEnsure-DirectoryExists -path $templateFileDir | Out-Null
            $zipitems = (Get-ChildItem -Path $templateSourceFolder -Recurse -File)
            InternalNew-ZipFile -ZipFilePath $templatefilepath -rootFolder $templateSourceFolder -InputObject $zipitems.FullName | Out-Null
        }

        # return the path to the caller
        $templatefilepath
    }
}

function InternalNew-VsTemplateZip{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$destpath,

        [Parameter(Position=1)]
        [string]$vstemplateFilePath
    )
    process{
        if([string]::IsNullOrEmpty($vstemplateFilePath)){
            $templateZipPath = (InternalGet-TemplateVsTemplateZipFile)
        }
        
        # copy zip file to temp
        $tempdir = Get-NewTempDir
        try{
            $newtempfilepath = (Join-Path (Get-NewTempDir) 'vstemplate.zip')
        
            if( (-not ([string]::IsNullOrWhiteSpace($destpath))) -and (test-path $destpath) ){
                Remove-Item $destpath | Write-Verbose
            }
        
            $parentdir = (Split-Path $destpath -Parent)
            if(-not (Test-Path $parentdir)){
                New-Item -Path $parentdir -ItemType Directory | Write-Verbose
            }

            Copy-Item $templateZipPath $destpath
        }
        finally{
            if( -not ([string]::IsNullOrWhiteSpace($tempdir)) -and (Test-Path $tempdir)){
                Remove-Item -Path $tempdir -Recurse | Write-Verbose
            }
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