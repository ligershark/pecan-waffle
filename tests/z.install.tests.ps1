[cmdletbinding()]
 param()

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}
$scriptDir = ((Get-ScriptDirectory) + "\")

function Ensure-PathExists{
    param([Parameter(Position=0)][System.IO.DirectoryInfo]$path)
    process{
        if($path -ne $null){
            if(-not (Test-Path $path.FullName)){
                New-Item -Path $path.FullName -ItemType Directory
            }
        }
    }
}

[System.IO.DirectoryInfo]$sourceRoot = (Join-Path $scriptDir '..\')

Describe 'install test'{
    It 'can run the install script w/o errors' {
        [System.IO.FileInfo]$pathToInstall = (Join-Path $scriptDir '..\install.ps1')

        {& $pathToInstall.FullName} | Should not throw
    }
    BeforeEach{
        Remove-Module pecan-waffle -Force -ErrorAction SilentlyContinue
    }
    AfterEach{
        Remove-Module pecan-waffle -Force -ErrorAction SilentlyContinue
    }
}