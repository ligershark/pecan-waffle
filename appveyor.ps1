
# execute the install script to make sure it succeeds
function InternalGet-ScriptDirectory{
    split-path (((Get-Variable MyInvocation -Scope 1).Value).MyCommand.Path)
}
$scriptDir = (InternalGet-ScriptDirectory)
[System.IO.DirectoryInfo]$appvDestDir = (join-path $scriptDir '.appveyor\dest')
if(-not (Test-Path $appvDestDir.FullName)){
    New-Item -Path $appvDestDir.FullName -ItemType Directory
}

#. .\install.ps1

Remove-Module pecan-waffle -Force -ErrorAction SilentlyContinue

[System.IO.FileInfo]$modPath = (get-item (join-path $scriptDir 'pecan-waffle.psm1'))
Import-Module $modPath.FullName -DisableNameChecking -Global

if(Test-Path $appvDestDir.FullName){
    Remove-Item $appvDestDir.FullName -Recurse -Force
}

'project: demo-singlefileproj' | Write-Host
Add-Project -templateName 'demo-singlefileproj' -destPath (join-path $appvDestDir.FullName 'single') -projectName 'DemoProjSingleItem'

'project: empty' | Write-Host
Add-Project -templateName 'aspnet5-empty' -destPath (join-path $appvDestDir.FullName 'empty') -projectName 'MyNewEmptyProj'

'project: api' | Write-Host
Add-Project -templateName 'aspnet5-webapi' -destPath (join-path $appvDestDir.FullName 'api') -projectName 'MyNewApiProj'

'Item: controllerjs ' | Write-Host
Add-Item -templateName 'demo-controllerjs' -destPath (join-path $appvDestDir.FullName 'item-controllerjs') -itemName 'newcontroller'

'Item: angular' | Write-Host
Add-Item -templateName 'demo-angularfiles' -destPath (join-path $appvDestDir.FullName 'item-demo-angularfiles') -itemName 'angular'
