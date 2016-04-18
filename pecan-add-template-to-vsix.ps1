[cmdletbinding()]
param(    
    #[Parameter(Position=0)]
    [string]$pwInstallBranch = 'dev',

    #[Parameter(Position=1,Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    #[ValidateScript({test-path $_ -PathType Leaf})]
    [string]$templateRootDir,
    
    #[Parameter(Position=3)]
    [ValidateNotNullOrEmpty()]
    #[ValidateScript({test-path $_ -PathType Leaf})]
    [string]$vsixFilePath,

    #[Parameter(Position=3)]
    [string]$relativePathInVsix = ('.\'),

    [string]$relPathForTemplatezip = ('Output\ProjectTemplates\CSharp\pecan-waffle\')
)
@'
 [pwInstallBranch={0}]
 [templateRootDir={1}]
 [vsixFilePath={2}]
 [relativePathInVsix={3}]
'@ -f $pwInstallBranch,$templateRootDir,$vsixFilePath,$relativePathInVsix | Write-Verbose

if(-not (Test-Path $vsixFilePath -PathType Leaf)){
    throw ('Did not find vsix file at [{0}]' -f $vsixFilePath)
}

if(-not (Test-Path $templateRootDir -PathType Container)){
    throw ('Did not find vsix file at [{0}]' -f $templateRootDir)
}

if([string]::IsNullOrWhiteSpace($pwInstallBranch)){ $pwInstallBranch = 'master' }

$env:EnableAddLocalSourceOnLoad =$false

# parameters declared here
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted | out-null

[System.Version]$minPwVersion = (New-Object -TypeName 'system.version' -ArgumentList '0.0.13.0')
$pwNeedsInstall = $true

# see if pw is already installed and has a high enough version
[System.Version]$installedVersion = $null
try{
    Import-Module pecan-waffle -ErrorAction SilentlyContinue | out-null
    $installedVersion = Get-PecanWaffleVersion
}
catch{
    $installedVersion = $null
}

if( ($installedVersion -ne $null) -and ($installedVersion.CompareTo($minPwVersion) -ge 0)){
    $pwNeedsInstall = $false
}

$localPath = $env:PWLocalPath

if( (-not [string]::IsNullOrWhiteSpace($localPath)) -and (Test-Path $localPath)){
    $pwNeedsInstall = $true
}

if($pwNeedsInstall){
    Remove-Module pecan-waffle -ErrorAction SilentlyContinue | Out-Null
    Remove-Module pecan-waffle-visualstudio -ErrorAction SilentlyContinue | Out-Null
    
    [System.IO.DirectoryInfo]$localInstallFolder = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\pecan-waffle"
    if(test-path $localInstallFolder.FullName){
        Remove-Item $localInstallFolder.FullName -Recurse
    }
    
    if( (-not [string]::IsNullOrWhiteSpace($localPath)) -and (Test-Path $localPath)){
        Import-Module "$localPath\pecan-waffle.psm1" -Global -DisableNameChecking
    }
    else{
        $installUrl = ('https://raw.githubusercontent.com/ligershark/pecan-waffle/{0}/install.ps1' -f $pwInstallBranch)
        &{set-variable -name pwbranch -value $pwInstallBranch;$wc=New-Object System.Net.WebClient;$wc.Proxy=[System.Net.WebRequest]::DefaultWebProxy;$wc.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;Invoke-Expression ($wc.DownloadString($installUrl))}
    }
}

$templatefiles = (Get-ChildItem $templateRootDir 'pw-templateinfo*.ps1' -Recurse -File).FullName
foreach($templateFilePath in $templatefiles){
    Add-TemplateToVsix -vsixFilePath $vsixFilePath -templateFilePath $templateFilePath -relativePathInVsix $relativePathInVsix
    $vstemplatefileinfo = ([System.IO.FileInfo]$vstemplatefile)
    # process all _project.vstemplate files
    $vstemplateFiles = (Get-ChildItem -Path ((get-item $templateFilePath).Directory.FullName) '_project.vstemplate' -Recurse -File).FullName
    if( ($vstemplateFiles -ne $null)){
        foreach($vstempfile in $vstemplateFiles){
            'Creating a .zip file for [{0}] and adding to [{1}]' -f $vstempfile,$vsixFilePath | Write-Verbose
            Add-VsTemplateToVsix -vsixFilePath $vsixFilePath -vsTemplateFilePath $vstempfile -relPathInVsix $relPathForTemplatezip
        }
    }
}