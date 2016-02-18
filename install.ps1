if([string]::IsNullOrWhiteSpace($pwbranch)){
    $pwbranch = 'master'
}

function EnsureDirectoryExists{
    param([Parameter(Position=0)][System.IO.DirectoryInfo]$path)
    process{
        if($path -ne $null){
            if(-not (Test-Path $path.FullName)){
                New-Item -Path $path.FullName -ItemType Directory
            }
        }
    }
}

function GetPsModulesPath{
    [cmdletbinding()]
    param()
    process{
        $Destination = $null
        if(Test-Path 'Env:PSModulePath'){
            $ModulePaths = @($Env:PSModulePath -split ';')
    
            $ExpectedUserModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath WindowsPowerShell\Modules
            $Destination = $ModulePaths | Where-Object { $_ -eq $ExpectedUserModulePath} | Select-Object -First 1
            if (-not $Destination) {
                $Destination = $ModulePaths | Select-Object -Index 0
            }
        }
        $Destination
    }
}

# 1. download .zip file from github
[System.IO.DirectoryInfo]$tempinstalldir = ('{0}\pecan-waffle\install\' -f $env:LOCALAPPDATA)
$zipurl = 'https://github.com/ligershark/pecan-waffle/archive/' + $pwbranch + '.zip'
'Download url [{0}]' -f $zipurl | Write-Output
[System.IO.FileInfo]$tempzipdest = (join-path $tempinstalldir.FullName 'pecan-waffle.zip')
EnsureDirectoryExists $tempzipdest.Directory.FullName

if(Test-Path $tempzipdest.FullName){
    Remove-Item $tempzipdest.FullName
}
(New-Object System.Net.WebClient).DownloadFile($zipurl,$tempzipdest.FullName)

# 2. extract .zip file to a temp dir in %localappdata%
[System.IO.DirectoryInfo]$tempextractdir = (join-path ($tempinstalldir.FullName) ([System.Guid]::NewGuid()))
EnsureDirectoryExists $tempextractdir.FullName

Add-Type -assembly “system.io.compression.filesystem”
[io.compression.zipfile]::ExtractToDirectory($tempzipdest.FullName, $tempextractdir.FullName)

$foldertocopy = ([System.IO.DirectoryInfo](Join-Path $tempextractdir.FullName ('pecan-waffle-' + $pwbranch) )).FullName

if( ($foldertocopy -eq $null) -or (-not (Test-Path $foldertocopy))){
    throw ('Unable to copy files to modules folder, bad value for foldertocopy [{0}]' -f $foldertocopy)
}

# 4. copy contents to ps modules folder
[System.IO.DirectoryInfo]$moduledestfolder = (Join-Path (GetPsModulesPath) 'pecan-waffle')
if( ($moduledestfolder -ne $null ) -and (Test-Path $moduledestfolder.FullName)){
    Remove-Item $moduledestfolder.FullName -Recurse -ErrorAction SilentlyContinue
}
EnsureDirectoryExists $moduledestfolder.FullName
Copy-Item $foldertocopy\* -Destination $moduledestfolder.FullName -Include * -Recurse

# 5. load module
[System.IO.FileInfo]$expectedmodpath = (Join-Path $moduledestfolder.FullName 'pecan-waffle.psm1')
if(-not (Test-Path $expectedmodpath.FullName)){
    throw ('Did not find module at [{0}]' -f $expectedmodpath.FullName)
}

Remove-Module pecan-waffle -ErrorAction SilentlyContinue
Import-Module $expectedmodpath.FullName -Global

# clean up
if(Test-Path $tempextractdir.FullName){
    Remove-Item $tempextractdir.FullName -Recurse -ErrorAction SilentlyContinue
}
