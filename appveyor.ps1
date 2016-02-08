
# execute the install script to make sure it succeeds

#. .\install.ps1

Remove-Module pecan-waffle -Force -ErrorAction SilentlyContinue

[System.IO.FileInfo]$modPath = get-item '.\pecan-waffle.psm1'
Import-Module $modPath.FullName -DisableNameChecking -Global

if(Test-Path '.\.appveyor'){
    Remove-Item '.\.appveyor' -Recurse -Force
}

[System.IO.DirectoryInfo]$destDir = '.\.appveyor\dest'
if(-not (Test-Path $destDir.FullName)){
    New-Item -Path $destDir.FullName -ItemType Directory
}

'project: demo-singlefileproj' | Write-Host
Add-Project -templateName 'demo-singlefileproj' -destPath (join-path $destDir.FullName 'single') -projectName 'DemoProjSingleItem'
'project: empty' | Write-Host
Add-Project -templateName 'aspnet5-empty' -destPath (join-path $destDir.FullName 'empty') -projectName 'MyNewEmptyProj'
'project: api' | Write-Host
Add-Project -templateName 'aspnet5-webapi' -destPath (join-path $destDir.FullName 'api') -projectName 'MyNewApiProj'
'Item: controllerjs ' | Write-Host
Add-Item -templateName 'demo-controllerjs' -destPath (join-path $destDir.FullName 'item-controllerjs') -itemName 'newcontroller'
'Item: angular' | Write-Host
Add-Item -templateName 'demo-angularfiles' -destPath (join-path $destDir.FullName 'item-demo-angularfiles') -itemName 'newcontroller'
