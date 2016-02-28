param($templateName,$projectname,$destpath,$pwInstallBranch,$templateSource,$templateSourceBranch)

if([string]::IsNullOrWhiteSpace($templateName)){ throw ('$templateName is null') }
if([string]::IsNullOrWhiteSpace($projectname)){ throw ('$projectname is null') }
if([string]::IsNullOrWhiteSpace($destpath)){ throw ('$destpath is null') }

if([string]::IsNullOrWhiteSpace($pwInstallBranch)){ $pwInstallBranch = 'master' }
if([string]::IsNullOrWhiteSpace($templateSourceBranch)){ $templateSourceBranch = 'master' }

$destpath = ([System.IO.DirectoryInfo]$destpath)

# parameters declared here
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted | out-null

[System.Version]$minPwVersion = (New-Object -TypeName 'system.version' -ArgumentList '0.0.1.0')
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

if($pwNeedsInstall){
    Remove-Module pecan-waffle -ErrorAction SilentlyContinue | Out-Null
    
    [System.IO.DirectoryInfo]$localInstallFolder = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\pecan-waffle"
    if(test-path $localInstallFolder.FullName){
        Remove-Item $localInstallFolder.FullName -Recurse
    }

    $installUrl = ('https://raw.githubusercontent.com/ligershark/pecan-waffle/{0}/install.ps1' -f $pwInstallBranch)
    &{set-variable -name pwbranch -value $pwInstallBranch;$wc=New-Object System.Net.WebClient;$wc.Proxy=[System.Net.WebRequest]::DefaultWebProxy;$wc.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;Invoke-Expression ($wc.DownloadString($installUrl))}
}

if(-not [string]::IsNullOrWhiteSpace($templateSource)){
    Add-PWTemplateSource -path $templateSource -branch $templateSourceBranch
    # TODO: Update to just update this specific template
    Update-RemoteTemplates
}

New-PWProject -templateName $templatename -destPath $destpath.FullName -projectName $projectname -noNewFolder