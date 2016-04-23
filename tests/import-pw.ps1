
function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$scriptDir = ((Get-ScriptDirectory) + "\")
$moduleName = 'pecan-waffle'
$modulePath = ([System.IO.DirectoryInfo](Join-Path -Path $scriptDir -ChildPath ("..\{0}.psm1" -f $moduleName))).FullName
$env:IsDeveloperMachine=$true
if(Test-Path $modulePath){
    "Importing module from [{0}]" -f $modulePath | Write-Verbose

    if((Get-Module $moduleName)){
        Remove-Module $moduleName
    }
    
    Import-Module $modulePath -PassThru -DisableNameChecking | Out-Null
    Add-PWTemplateSource -path (join-path (Get-ScriptDirectory) '..\templates\samples')
}
else{
    'Unable to find module at [{0}]' -f $modulePath | Write-Error
	return
}

# shared functions declared here
function global:Create-TestFileAt{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [System.IO.FileInfo]$path,

        [Parameter(Position=1)]
        [string]$content = ('test file created at {0}' -f [DateTime]::Now)
    )
    process{
        if(-not (Test-Path $path.FullName)){
            Ensure-PathExists $path.DirectoryName
            New-Item -Path $path.FullName -ItemType File -Value $content
        }

    }
}

function global:Ensure-PathExists{
    param([Parameter(Position=0)][System.IO.DirectoryInfo]$path)
    process{
        if($path -ne $null){
            if(-not (Test-Path $path.FullName)){
                New-Item -Path $path.FullName -ItemType Directory
            }
        }
    }
}
