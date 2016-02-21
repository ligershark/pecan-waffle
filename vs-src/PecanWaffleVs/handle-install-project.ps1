
# parameters declared here
if([string]::IsNullOrWhiteSpace($installurl)){
    $installurl = 'https://raw.githubusercontent.com/ligershark/pecan-waffle/master/install.ps1'
}


Remove-Module pecan-waffle -Force;Import-Module C:\data\mycode\pecan-waffle\pecan-waffle.psm1 -Global -DisableNameChecking
$templatename = 'aspnet5-empty'
$projectname = 'mynewproject'
$destpath = 'c:\temp\pw\fromvs\'

$destpath = ([System.IO.DirectoryInfo]$destpath)

New-PWProject -templateName $templatename -destPath $destpath.FullName -projectName $projectname

# ensure pecan-waffle is installed

# add the template source

# add the project