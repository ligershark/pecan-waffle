[cmdletbinding()]
param()

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}
$scriptDir = ((Get-ScriptDirectory) + "\")

$importPecanWaffle = (Join-Path -Path $scriptDir -ChildPath 'import-pw.ps1')

# import the module
. $importPecanWaffle

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

Describe 'InternalGet-TemplateVsTemplateZipFile tests'{
    It 'can create the file'{
        #  
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'getvstemplate01')
        Ensure-PathExists -path $dest.FullName
        { InternalGet-TemplateVsTemplateZipFile -templatefilepath (Join-Path $dest.FullName 'test.zip') } | should not throw
    }
}
