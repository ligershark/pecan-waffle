[cmdletbinding()]
param(
    [Parameter(Position=0)]
    [string]$configuration = 'Release'
)

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$scriptDir = ((Get-ScriptDirectory) + "\")
<#
.SYNOPSIS
    You can add this to you build script to ensure that psbuild is available before calling
    Invoke-MSBuild. If psbuild is not available locally it will be downloaded automatically.
#>
function EnsurePsbuildInstlled{
    [cmdletbinding()]
    param(
        [string]$psbuildInstallUri = 'https://raw.githubusercontent.com/ligershark/psbuild/master/src/GetPSBuild.ps1'
    )
    process{
        if(-not (Get-Command "Invoke-MsBuild" -errorAction SilentlyContinue)){
            'Installing psbuild from [{0}]' -f $psbuildInstallUri | Write-Verbose
            (new-object Net.WebClient).DownloadString($psbuildInstallUri) | iex
        }
        else{
            'psbuild already loaded, skipping download' | Write-Verbose
        }

        # make sure it's loaded and throw if not
        if(-not (Get-Command "Invoke-MsBuild" -errorAction SilentlyContinue)){
            throw ('Unable to install/load psbuild from [{0}]' -f $psbuildInstallUri)
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
            $pesterArgs.Add('-CodeCoverage','..\pecan-waffle.psm1')
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
        Invoke-MSBuild -projectsToBuild $slnfile.FullName -visualStudioVersion 14.0 -configuration $configuration -outputpath $vsoutputpath.FullName
    }
}

# begin script

[System.IO.FileInfo]$slnfile = "$scriptDir\vs-src\PecanWaffleVs.sln"
[System.IO.DirectoryInfo]$outputroot="$scriptDir\OutputRoot"
try{
    $env:IsDeveloperMachine=$true
    Remove-LocalInstall
    EnsurePsbuildInstlled

    CleanOutputFolder
    RestoreNuGetPackages
    BuildSolution

    Run-Tests -testDirectory (Join-Path $scriptDir 'tests')
}
catch{
    throw ( 'Build error {0} {1}' -f $_.Exception, (Get-PSCallStack|Out-String) )
}
finally{
    $oldIsDevMachineValue = $env:IsDeveloperMachine
}

