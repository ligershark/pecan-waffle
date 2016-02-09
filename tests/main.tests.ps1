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

        (Join-Path $dest.FullName 'MyNewEmptyProj.xproj') | should exist
        (Join-Path $dest.FullName 'project.json') | should exist
        (Join-Path $dest.FullName 'project.lock.json') | should not exist

        (Join-Path $dest.FullName 'MyNewEmptyProj.xproj') | should contain 'MyNewEmptyProj'
        (Join-Path $dest.FullName 'MyNewEmptyProj.xproj') | should not contain 'EmptyProject'
    }

    It 'can run demo-singlefileproj project'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'singlefileproj')
        if(-not (Test-Path $dest.FullName)){
            New-Item -Path $dest.FullName -ItemType Directory
        }

        { Add-Project -templateName 'demo-singlefileproj' -destPath $dest.FullName -projectName 'DemoProjSingleItem' } |should not throw
        (Get-ChildItem -Path $dest.FullName -File).Count | should be 1
        (Join-Path $dest.FullName 'DemoProjSingleItem.xproj') | should exist

        (Join-Path $dest.FullName 'DemoProjSingleItem.xproj') | should contain 'DemoProjSingleItem'
        (Join-Path $dest.FullName 'DemoProjSingleItem.xproj') | should not contain '$safeitemname$'
    }

    It 'can run aspnet5-webapi project'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'webapi')
        if(-not (Test-Path $dest.FullName)){
            New-Item -Path $dest.FullName -ItemType Directory
        }

        { Add-Project -templateName 'aspnet5-webapi' -destPath $dest.FullName -projectName 'MyNewApiProj' } |should not throw

        (Join-Path $dest.FullName 'MyNewApiProj.xproj') | should exist
        (Join-Path $dest.FullName 'project.json') | should exist
        (Join-Path $dest.FullName 'project.lock.json') | should not exist

        (Join-Path $dest.FullName 'MyNewApiProj.xproj') | should contain 'MyNewApiProj'
        (Join-Path $dest.FullName 'MyNewApiProj.xproj') | should not contain 'WebApiProject'
    }

    It 'can run demo-angularfiles project'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'angularfiles')
        if(-not (Test-Path $dest.FullName)){
            New-Item -Path $dest.FullName -ItemType Directory
        }

        { Add-Item -templateName 'demo-angularfiles' -destPath $dest.FullName -itemName 'angular' } | should not throw
        
        (Join-Path $dest.FullName 'controller.js') | should exist
        (Join-Path $dest.FullName 'directive.js') | should exist
        
        (Join-Path $dest.FullName 'controller.js') | should contain 'angular'
        (Join-Path $dest.FullName 'controller.js') | should not contain '$safeitemname$'
        $countTemplateFiles = (Get-ChildItem (Join-Path $scriptDir '..\templates\samples\item-templates\') -Exclude 'pw-templ*').Count
        $countDestFiles = (Get-ChildItem $dest.FullName).Count
        $countDestFiles | should be $countTemplateFiles
    }
}
