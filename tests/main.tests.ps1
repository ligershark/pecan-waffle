[cmdletbinding()]
 param()

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$scriptDir = ((Get-ScriptDirectory) + "\")

$importPsbuild = (Join-Path -Path $scriptDir -ChildPath 'import-pw.ps1')
# . $importPsbuild

Describe 'install test'{
    It 'can run the install script w/o errors' {
        [System.IO.FileInfo]$pathToInstall = (Join-Path $scriptDir '..\install.ps1')

        {& $pathToInstall.FullName} | Should not throw
    }
    BeforeEach{
        Remove-Module pecan-waffle -Force -ErrorAction SilentlyContinue
    }
    AfterEach{
        Remove-Module pecan-waffle -Force -ErrorAction SilentlyContinue
    }
}

Describe 'can add projects'{
    # import the module
    . $importPsbuild
    It 'can run aspnet5-empty project'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'empty01')
        if(-not (Test-Path $dest.FullName)){
            New-Item -Path $dest.FullName -ItemType Directory
        }

        { Add-Project -templateName 'aspnet5-empty' -destPath $dest.FullName -projectName 'MyNewEmptyProj' } |should not throw
    }

    It 'can run demo-singlefileproj project'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'singlefileproj')
        if(-not (Test-Path $dest.FullName)){
            New-Item -Path $dest.FullName -ItemType Directory
        }

        { Add-Project -templateName 'demo-singlefileproj' -destPath $dest.FullName -projectName 'DemoProjSingleItem' } |should not throw
    }

    It 'can run aspnet5-webapi project'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'webapi')
        if(-not (Test-Path $dest.FullName)){
            New-Item -Path $dest.FullName -ItemType Directory
        }

        { Add-Project -templateName 'aspnet5-webapi' -destPath $dest.FullName -projectName 'MyNewApiProj' } |should not throw
    }

    It 'can run singlefileproj project'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'empty01')
        if(-not (Test-Path $dest.FullName)){
            New-Item -Path $dest.FullName -ItemType Directory
        }

        Add-Item -templateName 'demo-angularfiles' -destPath $dest.FullName -itemName 'newcontroller'
    }

    It 'can run demo-angularfiles project'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'angularfiles')
        if(-not (Test-Path $dest.FullName)){
            New-Item -Path $dest.FullName -ItemType Directory
        }

        Add-Item -templateName 'demo-angularfiles' -destPath $dest.FullName -itemName 'angular'
    }
}
<#
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
#>