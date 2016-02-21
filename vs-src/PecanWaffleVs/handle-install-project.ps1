
# parameters declared here
if([string]::IsNullOrWhiteSpace($installurl)){
    $installurl = 'https://raw.githubusercontent.com/ligershark/pecan-waffle/master/install.ps1'
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned | out-null
$pwNeedsInstall = $true
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
    # TODO: Update branch to master or via parameter
    &{set-variable -name pwbranch -value 'dev';$wc=New-Object System.Net.WebClient;$wc.Proxy=[System.Net.WebRequest]::DefaultWebProxy;$wc.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;Invoke-Expression ($wc.DownloadString('https://raw.githubusercontent.com/ligershark/pecan-waffle/dev/install.ps1'))}
}

Remove-Module pecan-waffle -Force -ErrorAction SilentlyContinue | out-null
Import-Module '{2}' -Global -DisableNameChecking
$templatename = 'aspnet5-empty'
$projectname = '{0}'
$destpath = '{1}'

$destpath = ([System.IO.DirectoryInfo]$destpath)

New-PWProject -templateName $templatename -destPath $destpath.FullName -projectName $projectname -noNewFolder

# ensure pecan-waffle is installed

# add the template source

# add the project

# $branch = 'dev'
# &{set-variable -name pwbranch -value 'dev';$wc=New-Object System.Net.WebClient;$wc.Proxy=[System.Net.WebRequest]::DefaultWebProxy;$wc.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;Invoke-Expression ($wc.DownloadString('https://raw.githubusercontent.com/ligershark/pecan-waffle/dev/install.ps1'))}