function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}
$scriptDir = ((Get-ScriptDirectory) + "\")

$originalPwLocalPath = $env:PWLocalPath
$env:PWLocalPath = ([System.IO.DirectoryInfo](Join-Path $scriptDir ..\)).FullName

$pwAddTemplateScript = ([System.IO.FileInfo](Join-Path $scriptDir '..\pecan-add-template-to-vsix.ps1')).FullName

if(-not (Test-Path $pwAddTemplateScript)){
    throw ('add template to vsix script not found at [{0}]' -f $pwAddTemplateScript)
}


$importPecanWaffle = (Join-Path -Path $scriptDir -ChildPath 'import-pw.ps1')
# import the module to get the shared functions defined in the file

$pwtemplatecontent = @'
[cmdletbinding()]
param()

$templateInfo = New-Object -TypeName psobject -Property @{{
    Name = '{0}'
    Type = 'ProjectTemplate'
}}

Set-TemplateInfo -templateInfo $templateInfo
'@

Describe 'can call add-template-to-vsix'{
    . $importPecanWaffle
    Remove-Module pecan-waffle -ErrorAction SilentlyContinue | Out-Null
    Remove-Module pecan-waffle-visualstudio -ErrorAction SilentlyContinue | Out-Null

    It 'can call add-template-to-vsix'{
        $testname = 'call-add-to-vsix-01'
        [string]$templateSource = ([System.IO.DirectoryInfo](Join-Path $TestDrive "$testname\src")).FullName
        Ensure-PathExists -path $templateSource        

        Create-TestFileAt -path (Join-Path $templateSource 'WebApiProject.xproj') -content '* WebApiProject.xproj *'
        Create-TestFileAt -path (Join-Path $templateSource 'otherfile.json')
        Create-TestFileAt -path (Join-Path $templateSource '_project.vstemplate')

        $templatecontent = ($pwtemplatecontent -f $testname)
        Create-TestFileAt -path (Join-Path $templateSource 'pw-templateinfo.ps1') -content $templatecontent

        [string]$outdir = ([System.IO.DirectoryInfo](Join-Path $TestDrive "$testname\dest")).FullName        
        Ensure-PathExists -path $dest
        # shouldn't be used
        [string]$installBranch = 'doesnt-exist'
        [string]$templateDir = $templateSource
        [string]$relpath = 'output\projecttemplates\unittest'
        & $pwAddTemplateScript -pwInstallBranch $installbranch -templateRootDir $templateDir -outputDirectory $outdir -relPathForTemplatezip $relpath

        (Join-Path $outdir "templates\$testname\WebApiProject.xproj") | should exist
        (Join-Path $outdir "templates\$testname\pw-templateinfo.ps1") | should exist
        (Join-Path $outdir "templates\$testname\otherfile.json") | should exist
        (Join-Path $outdir "output\projecttemplates\unittest\VsTemplateProj1.project.zip") | should exist
    }
}

$env:PWLocalPath = $originalPwLocalPath