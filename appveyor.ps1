
# run the build script
function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$scriptDir = ((Get-ScriptDirectory) + "\")

try{
    [System.IO.FileInfo]$buildFile = (Join-Path $scriptDir 'build.ps1')

    $env:PesterEnableCodeCoverage = $true
    $env:ExitOnPesterFail = $true

    if($env:APPVEYOR_REPO_BRANCH -eq 'release' -and ([string]::IsNullOrWhiteSpace($env:APPVEYOR_PULL_REQUEST_NUMBER) )) {
        . $buildFile.FullName -publishToNuget
    }
    else{
        . $buildFile.FullName
    }
    
}
catch{
    throw ( 'Build error {0} {1}' -f $_.Exception, (Get-PSCallStack|Out-String) )
}