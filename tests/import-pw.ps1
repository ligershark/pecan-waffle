
function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$scriptDir = ((Get-ScriptDirectory) + "\")
$moduleName = 'pecan-waffle'
$modulePath = (Join-Path -Path $scriptDir -ChildPath ("..\{0}.psm1" -f $moduleName))
$env:IsDeveloperMachine=$true
if(Test-Path $modulePath){
    "Importing module from [{0}]" -f $modulePath | Write-Verbose

    if((Get-Module $moduleName)){
        Remove-Module $moduleName
    }
    
    Import-Module $modulePath -PassThru -DisableNameChecking | Out-Null
}
else{
    'Unable to find module at [{0}]' -f $modulePath | Write-Error
	return
}


