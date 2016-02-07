
# execute the install script to make sure it succeeds

. .\install.ps1

[System.IO.DirectoryInfo]$destDir = 'C:\temp\pecan-waffle\appveyor\dest'
if(-not (Test-Path $destDir.FullName)){
    New-Item -Path $destDir.FullName -ItemType Directory
}

Add-Project -templateName 'demo-singlefileproj' -destPath (join-path $destDir.FullName 'single') -projectName 'DemoProjSingleItem'
Add-Project -templateName 'aspnet5-empty' -destPath (join-path $destDir.FullName 'empty') -projectName 'MyNewEmptyProj'
Add-Project -templateName 'aspnet5-webapi' -destPath (join-path $destDir.FullName 'api') -projectName 'MyNewApiProj'