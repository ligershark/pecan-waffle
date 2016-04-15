[cmdletbinding()]
param(    
    [Parameter(Position=0)]
    [string]$pwInstallBranch = 'dev',

    [Parameter(Position=1,Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$templateName,

    [Parameter(Position=1,Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({test-path $_ -PathType Leaf})]
    [string]$templateFilePath,
    
    [Parameter(Position=3)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({test-path $_ -PathType Leaf})]
    [string]$vsixFilePath,

    [Parameter(Position=3)]
    [string]$relativePathInVsix = ('.\')

)
#&{set-variable -name pwbranch -value 'master';$wc=New-Object System.Net.WebClient;$wc.Proxy=[System.Net.WebRequest]::DefaultWebProxy;$wc.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;Invoke-Expression ($wc.DownloadString('https://raw.githubusercontent.com/ligershark/pecan-waffle/master/install.ps1'))}
if([string]::IsNullOrWhiteSpace($templateName)){ throw ('$templateName is null') }
if([string]::IsNullOrWhiteSpace($pwInstallBranch)){ $pwInstallBranch = 'master' }

$env:EnableAddLocalSourceOnLoad =$false

# parameters declared here
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted | out-null

[System.Version]$minPwVersion = (New-Object -TypeName 'system.version' -ArgumentList '0.0.2.0')
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

Add-TemplateToVsix -vsixFilePath $vsixFilePath -templateFilePath $templateFilePath -templateName $templateName -relativePathInVsix $relativePathInVsix