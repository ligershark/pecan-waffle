[cmdletbinding()]
param(
    # TODO: Remove this parameter
    [string]$pwInstallBranch = 'dev',

    [ValidateNotNullOrEmpty()]

    [string]$templateRootDir,

    [string]$outputDirectory,

    [string]$relPathForTemplatezip = ('Output\ProjectTemplates\CSharp\pecan-waffle\')
)
@'
 [pwInstallBranch={0}]
 [templateRootDir={1}]
 [vsixFilePath={2}]
 [outputDirectory={3}]
'@ -f $pwInstallBranch,$templateRootDir,$vsixFilePath,$outputDirectory | Write-Verbose

if(-not (Test-Path $templateRootDir -PathType Container)){
    throw ('Did not find template root folder at [{0}]' -f $templateRootDir)
}

function InternalGet-ScriptDirectory{
    split-path (((Get-Variable MyInvocation -Scope 1).Value).MyCommand.Path)
}
$scriptdir = (InternalGet-ScriptDirectory)

# parameters declared here
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted | out-null

$importPath = (join-path $scriptdir 'pecan-waffle.psm1')

if( -not ([string]::IsNullOrWhiteSpace($env:PWLocalPath)) -and (test-path ($env:PWLocalPath))){
    $importPath = (join-path $env:PWLocalPath 'pecan-waffle.psm1')
}

if(-not (Test-Path $importPath -PathType Leaf)){
    throw ('pecan-waffle module not found at [{0}]' -f $importPath)
}

Import-Module $importPath -Global -DisableNameChecking

$templatefiles = (Get-ChildItem $templateRootDir 'pw-templateinfo*.ps1' -Recurse -File).FullName
foreach($templateFilePath in $templatefiles){
    if(-not (Test-Path $outputDirectory)){
        New-Item -Path $outputDirectory -ItemType Directory
    }
    $templatesOutput = (Join-Path $outputDirectory 'templates')
    if(-not (Test-Path $templatesOutput)){
        New-Item -Path $templatesOutput -ItemType Directory
    }
    Copy-TemplatesTo -templateFilePath $templateFilePath -outputDirectry $templatesOutput
    
    $templateOutputdir = (Join-Path $outputDirectory $relPathForTemplatezip)
    if(-not (Test-Path $templateOutputdir)){
        New-Item $templateOutputdir -ItemType Directory
    }
    
    $vstemplatefileinfo = ([System.IO.FileInfo]$vstemplatefile)
    # process all _project.vstemplate files
    $vstemplateFiles = (Get-ChildItem -Path ((get-item $templateFilePath).Directory.FullName) '_project.vstemplate' -Recurse -File).FullName
    if( ($vstemplateFiles -ne $null)){
        foreach($vstempfile in $vstemplateFiles){
            'Creating a .zip file for [{0}] and adding to [{1}]' -f $vstempfile,$vsixFilePath | Write-Verbose
            New-VsTemplateZipFile -vsTemplateFilePath $vstempfile -outputDirectory $templateOutputdir
        }
    }
}