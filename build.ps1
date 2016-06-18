[cmdletbinding(DefaultParameterSetName='build')]
param(
    [Parameter(ParameterSetName='build',Position=0)]
    [string]$configuration = 'Release',

    [Parameter(ParameterSetName='build',Position=1)]
    [switch]$noTests,

    [Parameter(ParameterSetName='build',Position=2)]
    [switch]$publishToNuget,

    [Parameter(ParameterSetName='build',Position=3)]
    [string]$nugetApiKey = ($env:NuGetApiKey),

    # version parameters
    [Parameter(ParameterSetName='setversion',Position=10)]
    [switch]$setversion,

    [Parameter(ParameterSetName='setversion',Position=11,Mandatory=$true)]
    [string]$newversion,

    [Parameter(ParameterSetName='getversion',Position=0)]
    [switch]$getversion,

    [Parameter(ParameterSetName='delfolders',Position=0)]
    [switch]$deleteTempFolders
)

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$scriptDir = ((Get-ScriptDirectory) + "\")
$localNugetFolder = 'c:\temp\nuget\local'
[System.IO.FileInfo]$slnfile = (join-path $scriptDir 'vs-src\PecanWaffleVs.sln')
[System.IO.DirectoryInfo]$outputroot=(join-path $scriptDir 'OutputRoot')
[System.IO.DirectoryInfo]$outputPathNuget = (Join-Path $outputroot '_nuget-pkg')

function EnsurePsbuildInstlled{
    [cmdletbinding()]
    param(
        # TODO: Change to master when 1.1.9 gets there
        [string]$psbuildInstallUri = 'https://raw.githubusercontent.com/ligershark/psbuild/dev/src/GetPSBuild.ps1',

        [System.Version]$minVersion = (New-Object -TypeName 'system.version' -ArgumentList '1.1.9.1')
    )
    process{
        # see if there is already a version loaded
        $psbuildNeedsInstall = $true
        [System.Version]$installedVersion = $null
        try{
            Import-Module psbuild -ErrorAction SilentlyContinue | Out-Null
            $installedVersion = Get-PSBuildVersion
        }
        catch{
            $installedVersion = $null
        }

        if( ($installedVersion -ne $null) -and ($installedVersion.CompareTo($minVersion) -ge 0) ){
            'Skipping psbuild install because version [{0}] detected' -f $installedVersion.ToString() | Write-Verbose
        }
        else{
            'Installing psbuild from [{0}]' -f $psbuildInstallUri | Write-Verbose
            (new-object Net.WebClient).DownloadString($psbuildInstallUri) | iex

            # make sure it's loaded and throw if not
            if(-not (Get-Command "Invoke-MsBuild" -errorAction SilentlyContinue)){
                throw ('Unable to install/load psbuild from [{0}]' -f $psbuildInstallUri)
            }
        }
    }
}

function EnsureFileReplacerInstlled{
    [cmdletbinding()]
    param()
    begin{
        Import-NuGetPowershell
    }
    process{
        if(-not (Get-Command -Module file-replacer -Name Replace-TextInFolder -errorAction SilentlyContinue)){
            $fpinstallpath = (Get-NuGetPackage -name file-replacer -version '0.4.0-beta' -binpath)
            if(-not (Test-Path $fpinstallpath)){ throw ('file-replacer folder not found at [{0}]' -f $fpinstallpath) }
            Import-Module (Join-Path $fpinstallpath 'file-replacer.psm1') -DisableNameChecking
        }

        # make sure it's loaded and throw if not
        if(-not (Get-Command -Module file-replacer -Name Replace-TextInFolder -errorAction SilentlyContinue)){
            throw ('Unable to install/load file-replacer')
        }
    }
}
function InternalEnsure-DirectoryExists{
    param([Parameter(Position=0)][System.IO.DirectoryInfo]$path)
    process{
        if($path -ne $null){
            if(-not (Test-Path $path.FullName)){
                New-Item -Path $path.FullName -ItemType Directory
            }
        }
    }
}
<#
.SYNOPSIS 
This will inspect the nuspec file and return the value for the Version element.
#>
function GetExistingVersion{
    [cmdletbinding()]
    param(
        [ValidateScript({test-path $_ -PathType Leaf})]
        $nuspecFile = (Join-Path $scriptDir 'pecan-waffle.nuspec')
    )
    process{
        ([xml](Get-Content $nuspecFile)).package.metadata.version
    }
}

function SetVersion{
    [cmdletbinding()]
    param(
        [Parameter(Position=1,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$newversion,

        [Parameter(Position=2)]
        [ValidateNotNullOrEmpty()]
        [string]$oldversion = (GetExistingVersion),

        [Parameter(Position=3)]
        [string]$filereplacerVersion = '0.4.0-beta'
    )
    begin{
        EnsureFileReplacerInstlled
    }
    process{
        $folder = $scriptDir
        $include = '*.nuspec;*.ps*1;*.ps1'
        # In case the script is in the same folder as the files you are replacing add it to the exclude list
        $exclude = "$($MyInvocation.MyCommand.Name);"
        $exclude += '*.psd1;build.ps1'
        $replacements = @{
            "$oldversion"="$newversion"
        }
        Replace-TextInFolder -folder $folder -include $include -exclude $exclude -replacements $replacements | Write-Verbose

        # update the .psd1 file if there is one
        $replacements = @{
            ($oldversion.Replace('-beta','.0'))=($newversion.Replace('-beta','.0'))
        }
        Replace-TextInFolder -folder $folder -include '*.psd1;*.cs;*.ps*1' -exclude $exclude -replacements $replacements | Write-Verbose
        'Replacement complete' | Write-Verbose
    }
}

function Import-Pester2{
    [cmdletbinding()]
    param(
        $pesterVersion = '3.3.14'
    )
    process{
        Import-NuGetPowershell

        Remove-Module pester -ErrorAction SilentlyContinue

        [System.IO.DirectoryInfo]$pesterDir = (Get-NuGetPackage -name 'pester' -version $pesterVersion -binpath)
        [System.IO.FileInfo]$pesterModPath = (Join-Path $pesterDir.FullName 'pester.psd1')
        if(-not (Test-Path $pesterModPath.FullName)){
            throw ('Pester not found at [{0}]' -f $pesterModPath.FullName)
        }

        Import-Module $pesterModPath.FullName -Global
    }
}

function Run-Tests{
    [cmdletbinding()]
    param(
        $testDirectory = (join-path $scriptDir tests)
    )
    begin{ 
        Import-Pester2 -pesterVersion 3.3.14
    }
    process{
        # go to the tests directory and run pester
        push-location
        set-location $testDirectory
     
        $pesterArgs = @{
            '-PassThru' = $true
        }
        if($env:ExitOnPesterFail -eq $true){
            $pesterArgs.Add('-EnableExit',$true)
        }
        if( $env:PesterEnableCodeCoverage -eq $true){
            $pesterArgs.Add('-CodeCoverage',('..\pecan-waffle.psm1','..\pecan-waffle-visualstudio.psm1','..\pecan-add-template-to-vsix.ps1'))
        }

        $pesterResult = Invoke-Pester @pesterArgs
        pop-location

        if($pesterResult.FailedCount -gt 0){
            throw ('Failed test cases: {0}' -f $pesterResult.FailedCount)
        }
    }
}

function Remove-LocalInstall {
    [cmdletbinding()]
    param()
    process{
        [System.IO.DirectoryInfo]$localInstallFolder = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\pecan-waffle"
        if(test-path $localInstallFolder.FullName){
            Remove-Item $localInstallFolder.FullName -Recurse
        }
    }
}

function CleanOutputFolder{
    [cmdletbinding()]
    param()
    process{
        if( ($outputroot -eq $null) -or ([string]::IsNullOrWhiteSpace($outputroot.FullName))){
            return
        }
        elseif(Test-Path $outputroot.FullName){
            'Removing output folder at [{0}]' -f $outputroot.FullName | Write-Output
            Remove-Item $outputroot -Recurse
        }
    }
}
function RestoreNuGetPackages(){
    [cmdletbinding()]
    param()
    process{
        $oldloc = Get-Location
        try{
            'restoring nuget packages' | Write-Output
            Set-Location $slnfile.Directory.FullName
            Invoke-CommandString -command (Get-Nuget) -commandArgs restore
        }
        finally{
            Set-Location $oldloc
        }
    }
}
function PublishNuGetPackage{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$nugetPackages,

        [Parameter(Mandatory=$true)]
        $nugetApiKey
    )
    process{
        foreach($nugetPackage in $nugetPackages){
            $pkgPath = (get-item $nugetPackage).FullName
            $cmdArgs = @('push',$pkgPath,$nugetApiKey,'-NonInteractive')

            'Publishing nuget package with the following args: [nuget.exe {0}]' -f ($cmdArgs -join ' ') | Write-Verbose
            &(Get-Nuget) $cmdArgs
        }
    }
}
function CopyStaticFilesToOutputDir{
    [cmdletbinding()]
    param()
    process{
        Get-ChildItem $scriptDir *.ps*1 | Copy-Item -Destination $outputroot
        Get-ChildItem $scriptDir *.nuspec | Copy-Item -Destination $outputroot
        Get-ChildItem $scriptDir *.targets | Copy-Item -Destination $outputroot
        Get-ChildItem $scriptDir *.props | Copy-Item -Destination $outputroot
        [System.IO.DirectoryInfo]$vstemplateDest =(Join-Path $outputroot vs-template-zip) 
        if(-not (Test-Path $vstemplateDest.FullName)) {
            Copy-Item (Join-Path $scriptDir 'vs-template-zip') -Destination $vstemplateDest.FullName -Recurse
        }
    }
}

function Build-NuGetPackage{
    [cmdletbinding()]
    param()
    process{
        if(-not (Test-Path $outputPathNuget)){
            New-Item -Path $outputPathNuget -ItemType Directory
        }

        Push-Location
        try{
            [string[]]$nuspecFilesToBuild = @()
            $nuspecFilesToBuild += ((Get-ChildItem $outputRoot '*.nuspec' -Recurse -File).FullName)

            foreach($nufile in $nuspecFilesToBuild){
                $nufile = [System.IO.FileInfo]$nufile
                Push-Location
                try{
                    Set-Location -Path ($nufile.Directory.FullName)
                    'Building nuget package for [{0}]' -f ($nufile.FullName) | Write-Verbose
                    Invoke-CommandString -command (Get-Nuget) -commandArgs @('pack',($nufile.Name),'-NoPackageAnalysis','-OutputDirectory',($outputPathNuget.FullName))
                }
                finally{
                    Pop-Location
                }
            }

            Copy-PackagesToLocalNuGetFolder
        }
        finally{
            Pop-Location
        }
    }
}

function Push-NugetPackageToFeed{
    [cmdletbinding()]
    param()
    process{
        if( (IsRunningInAppVeyor) ){
            if(-not ([string]::IsNullOrWhiteSpace($outputPathNuget)) -and (Test-Path $outputPathNuget)){
                $pkgstopush = (Get-ChildItem $outputPathNuget *.nupkg -Recurse -File)
                if($pkgstopush -ne $null){
                    foreach($pkg in $pkgstopush.FullName){
                        Push-AppveyorArtifact $pkg
                    }
                }
            }
        }
    }
}

function IsRunningInAppVeyor(){
    [cmdletbinding()]
    param()
    process{
        $pushartifactcommand = (get-command 'Push-AppveyorArtifact' -ErrorAction SilentlyContinue)
        if($pushartifactcommand -ne $null){
            $true
        }
        else{
            $false
        }
    }
}

function Copy-PackagesToLocalNuGetFolder{
    [cmdletbinding()]
    param(
        $outputFolder = $outputPathNuget
    )
    process{
        if(Test-Path $localNugetFolder){
            Get-ChildItem $outputFolder *.nupkg -Recurse -File|Copy-Item -Destination $localNugetFolder
        }
    }
}
function BuildSolution{
    [cmdletbinding()]
    param()
    process{
        if(-not (Test-Path $slnfile.FullName)){
            throw ('Solution not found at [{0}]' -f $slnfile.FullName)
        }
        if($outputroot -eq $null){
            throw ('output path is null')
        }

        [System.IO.DirectoryInfo]$vsoutputpath = (Join-Path $outputroot.FullName "vs")
        InternalEnsure-DirectoryExists -path $vsoutputpath.FullName

        'Building soution at [{0}]' -f $slnfile.FullName | Write-Output
        Invoke-MSBuild -projectsToBuild $slnfile.FullName -visualStudioVersion 14.0 -configuration $configuration -outputpath $vsoutputpath.FullName -properties @{'DeployExtension'=$false}
    }
}
function Update-FilesWithCommitId{
    [cmdletbinding()]
    param(
        [string]$commitId = ($env:APPVEYOR_REPO_COMMIT),

        [System.IO.DirectoryInfo]$dirToUpdate = ($outputroot),

        [Parameter(Position=2)]
        [string]$filereplacerVersion = '0.4.0-beta'
    )
    begin{
        EnsureFileReplacerInstlled
    }
    process{
        if([string]::IsNullOrEmpty($commitId)){
            try{
                $commitstr = (& git log --format="%H" -n 1)
                if($commitstr -match '\b[0-9a-f]{5,40}\b'){
                    $commitId = $commitstr
                }
            }
            catch{
                # do nothing
            }
        }

        if(![string]::IsNullOrWhiteSpace($commitId)){
            'Updating commitId from [{0}] to [{1}]' -f '$(COMMIT_ID)',$commitId | Write-Verbose

            $folder = $dirToUpdate
            $include = '*.nuspec'
            # In case the script is in the same folder as the files you are replacing add it to the exclude list
            $exclude = "$($MyInvocation.MyCommand.Name);"
            $replacements = @{
                '$(COMMIT_ID)'="$commitId"
            }
            Replace-TextInFolder -folder $folder -include $include -exclude $exclude -replacements $replacements | Write-Verbose
            'Replacement complete' | Write-Verbose
        }
    }
}

function DeleteAllTempFolders{
    [cmdletbinding()]
    param()
    process{
        $foldersToDelete =@(
            "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\nuget-powershell",
            "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\pecan-waffle",
            "$env:LOCALAPPDATA\LigerShark\nuget-ps",
            "$env:LOCALAPPDATA\pecan-waffle"

        )

        foreach($folder in $foldersToDelete){
            if( -not ([string]::IsNullOrWhiteSpace($folder)) -and (Test-Path $folder)){
                Remove-Item -Path $folder -Recurse
            }
        }
    }
}

function FullBuild{
    [cmdletbinding()]
    param()
    process{
        CleanOutputFolder
        InternalEnsure-DirectoryExists -path $outputroot
        Import-NuGetPowershell
        RestoreNuGetPackages

        CopyStaticFilesToOutputDir

        BuildSolution
        Update-FilesWithCommitId
        Build-NuGetPackage

        if(-not $noTests){
            Run-Tests -testDirectory (Join-Path $scriptDir 'tests')
        }

        Push-NugetPackageToFeed

        if($publishToNuget){
            (Get-ChildItem -Path ($outputPathNuget) 'pecan-*.nupkg').FullName | PublishNuGetPackage -nugetApiKey $nugetApiKey
        }
    }
}

# begin script

try{
    $env:IsDeveloperMachine=$true
    Remove-LocalInstall
    EnsurePsbuildInstlled

    $doBuild=$true

    if( ($getversion -eq $true) -or ($setversion -eq $true) -or ($deleteTempFolders -eq $true) ){
        $doBuild = $false
    }

    if($doBuild){
        FullBuild
    }

    if($getversion){
        GetExistingVersion
    }
    elseif($setversion -eq $true){
        SetVersion -newversion $newversion
    }
    elseif($deleteTempFolders){
        DeleteAllTempFolders
    }
}
catch{
    throw ( 'Build error {0} {1}' -f $_.Exception, (Get-PSCallStack|Out-String) )
}
finally{
    $oldIsDevMachineValue = $env:IsDeveloperMachine
}

