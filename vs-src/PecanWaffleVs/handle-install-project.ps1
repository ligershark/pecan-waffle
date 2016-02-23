param($templateName,$projectname,$destpath,$pwInstallBranch)

if([string]::IsNullOrWhiteSpace($templateName)){
    throw ('$templateName is null')
}
if([string]::IsNullOrWhiteSpace($projectname)){
    throw ('$projectname is null')
}
if([string]::IsNullOrWhiteSpace($destpath)){
    throw ('$destpath is null')
}

if([string]::IsNullOrWhiteSpace($pwInstallBranch)){
    $pwInstallBranch = 'master'
}

$destpath = ([System.IO.DirectoryInfo]$destpath)

# parameters declared here
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned | out-null

# TODO: Remove this later and detect version to see if upgrade is needed
$pwNeedsInstall = $true
[System.IO.DirectoryInfo]$localInstallFolder = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\pecan-waffle"
if(test-path $localInstallFolder.FullName){
    Remove-Item $localInstallFolder.FullName -Recurse
}

try{
    Import-Module pecan-waffle -ErrorAction SilentlyContinue | out-null

    if(-not (Get-Command "New-PWProject" -Module pecan-waffle  -errorAction SilentlyContinue)){
        $pwNeedsInstall = $true
    }
}
catch{
    # do nothing
}

if($pwNeedsInstall){
    Remove-Module pecan-waffle -ErrorAction SilentlyContinue | Out-Null
    # TODO: Update branch to master or via parameter
    $installUrl = ('https://raw.githubusercontent.com/ligershark/pecan-waffle/{0}/install.ps1' -f $pwInstallBranch)
    &{set-variable -name pwbranch -value $pwInstallBranch;$wc=New-Object System.Net.WebClient;$wc.Proxy=[System.Net.WebRequest]::DefaultWebProxy;$wc.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;Invoke-Expression ($wc.DownloadString($installUrl))}
}

New-PWProject -templateName $templatename -destPath $destpath.FullName -projectName $projectname -noNewFolder