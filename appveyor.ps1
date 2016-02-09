
# run the build script
$scriptDir = ((Get-ScriptDirectory) + "\")
[System.IO.FileInfo]$buildFile = (Join-Path $scriptDir 'build.ps1')

$env:PesterEnableCodeCoverage = $true
$env:ExitOnPesterFail = $true

. $buildFile.FullName
