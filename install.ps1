$url = 'https://raw.githubusercontent.com/ligershark/pecan-waffle/master/pecan-waffle.psm1'
[System.IO.FileInfo]$destfile = ('{0}\pecan-waffle\install\pecan-waffle.psm1' -f $env:LOCALAPPDATA)

if(-not (Test-Path $destfile.Directory.FullName)){
    New-Item -Path $destfile.Directory.FullName -ItemType Directory
}
if(Test-Path $destfile.FullName){
    Remove-Item $destfile.FullName
}
(New-Object System.Net.WebClient).DownloadFile($url, $destfile.FullName)

Import-Module $destfile.FullName -Global

Add-TemplateSource -url 'https://github.com/ligershark/pecan-waffle.git'