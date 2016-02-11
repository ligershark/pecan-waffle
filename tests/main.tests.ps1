[cmdletbinding()]
 param()

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}
$scriptDir = ((Get-ScriptDirectory) + "\")

function Ensure-PathExists{
    param([Parameter(Position=0)][System.IO.DirectoryInfo]$path)
    process{
        if($path -ne $null){
            if(-not (Test-Path $path.FullName)){
                New-Item -Path $path.FullName -ItemType Directory
            }
        }
    }
}

$importPecanWaffle = (Join-Path -Path $scriptDir -ChildPath 'import-pw.ps1')
# . $importPecanWaffle

[System.IO.DirectoryInfo]$sourceRoot = (Join-Path $scriptDir '..\')

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

Describe 'add project tests'{
    # import the module
    . $importPecanWaffle
    It 'can run aspnet5-empty project'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'empty01')
        Ensure-PathExists -path $dest.FullName

        { Add-Project -templateName 'aspnet5-empty' -destPath $dest.FullName -projectName 'MyNewEmptyProj' -noNewFolder } |should not throw

        (Join-Path $dest.FullName 'MyNewEmptyProj.xproj') | should exist
        (Join-Path $dest.FullName 'project.json') | should exist
        (Join-Path $dest.FullName 'project.lock.json') | should not exist

        (Join-Path $dest.FullName 'MyNewEmptyProj.xproj') | should contain 'MyNewEmptyProj'
        (Join-Path $dest.FullName 'MyNewEmptyProj.xproj') | should not contain 'EmptyProject'
    }

    It 'can run demo-singlefileproj project'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'singlefileproj')
        Ensure-PathExists -path $dest.FullName

        { Add-Project -templateName 'demo-singlefileproj' -destPath $dest.FullName -projectName 'DemoProjSingleItem' -noNewFolder } |should not throw
        (Get-ChildItem -Path $dest.FullName -File).Count | should be 1
        (Join-Path $dest.FullName 'DemoProjSingleItem.xproj') | should exist

        (Join-Path $dest.FullName 'DemoProjSingleItem.xproj') | should contain 'DemoProjSingleItem'
       (Join-Path $dest.FullName 'DemoProjSingleItem.xproj') | should not contain '$safeitemname$'
    }

    It 'can run aspnet5-webapi project'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'webapi')
        Ensure-PathExists -path $dest.FullName

        { Add-Project -templateName 'aspnet5-webapi' -destPath $dest.FullName -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        (Join-Path $dest.FullName 'MyNewApiProj.xproj') | should exist
        (Join-Path $dest.FullName 'project.json') | should exist
        (Join-Path $dest.FullName 'project.lock.json') | should not exist

        (Join-Path $dest.FullName 'MyNewApiProj.xproj') | should contain 'MyNewApiProj'
        (Join-Path $dest.FullName 'MyNewApiProj.xproj') | should not contain 'WebApiProject'
    }

    It 'will run beforeinstall' {
        # remove all templates
        Clear-AllTemplates

        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'demo01'
            Type = 'ProjectTemplate'
        }

        $Global:pwtestcount = 0
        beforeinstall -templateInfo $templateInfo -beforeInstall {$Global:pwtestcount++}

        [System.IO.DirectoryInfo]$emptyTemplatePath =(Join-Path $sourceRoot 'templates\aspnet5\EmptyProject')
        Set-TemplateInfo -templateInfo $templateInfo -templateRoot $emptyTemplatePath.FullName

        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'runbeforeinstall01')
        Ensure-PathExists -path $dest.FullName

        { Add-Project -templateName 'demo01' -destPath $dest.FullName -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        $Global:pwtestcount | should be 1
    }

    It 'will run afterinstall' {
        # remove all templates
        Clear-AllTemplates

        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'demo01'
            Type = 'ProjectTemplate'
        }

        $Global:pwtestcount = 0
        afterinstall -templateInfo $templateInfo -afterInstall {$Global:pwtestcount++}

        [System.IO.DirectoryInfo]$emptyTemplatePath =(Join-Path $sourceRoot 'templates\aspnet5\EmptyProject')
        Set-TemplateInfo -templateInfo $templateInfo -templateRoot $emptyTemplatePath.FullName

        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'runafterinstall01')
        Ensure-PathExists -path $dest.FullName

        { Add-Project -templateName 'demo01' -destPath $dest.FullName -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        $Global:pwtestcount | should be 1
    }

    It 'will run both before and after install'{
        # remove all templates
        Clear-AllTemplates

        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'demo01'
            Type = 'ProjectTemplate'
        }

        $Global:pwtestcount = 0
        beforeinstall -templateInfo $templateInfo -beforeInstall {$Global:pwtestcount++}
        afterinstall -templateInfo $templateInfo -afterInstall {$Global:pwtestcount++}

        [System.IO.DirectoryInfo]$emptyTemplatePath =(Join-Path $sourceRoot 'templates\aspnet5\EmptyProject')
        Set-TemplateInfo -templateInfo $templateInfo -templateRoot $emptyTemplatePath.FullName

        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'runbeforeafterinstall01')
        Ensure-PathExists -path $dest.FullName

        { Add-Project -templateName 'demo01' -destPath $dest.FullName -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        $Global:pwtestcount | should be 2
    }

    It 'will run both before and after install in order'{
        # remove all templates
        Clear-AllTemplates

        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'demo01'
            Type = 'ProjectTemplate'
        }

        
        beforeinstall -templateInfo $templateInfo -beforeInstall {
            $Global:pwtestbeforestart = [System.DateTime]::UtcNow
            sleep -Seconds 1
        }
        afterinstall -templateInfo $templateInfo -afterInstall {
            $Global:pwtestafterstart = [System.DateTime]::UtcNow
        }

        [System.IO.DirectoryInfo]$emptyTemplatePath =(Join-Path $sourceRoot 'templates\aspnet5\EmptyProject')
        Set-TemplateInfo -templateInfo $templateInfo -templateRoot $emptyTemplatePath.FullName

        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'runbeforeafterinstallordered01')
        Ensure-PathExists -path $dest.FullName

        { Add-Project -templateName 'demo01' -destPath $dest.FullName -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        $Global:pwtestbeforestart.CompareTo($Global:pwtestafterstart) | Should be -1
    }
}

Describe 'add item tests'{
    . $importPecanWaffle

    It 'can run demo-controllerjs item'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'controllerjs')
        if(-not (Test-Path $dest.FullName)){
            New-Item -Path $dest.FullName -ItemType Directory
        }

        { Add-Item -templateName 'demo-controllerjs' -destPath $dest.FullName -itemName 'MyController' } | should not throw
        
        (Join-Path $dest.FullName 'MyController.js') | should exist
        (Join-Path $dest.FullName 'directive.js') | should not exist
        
        (Join-Path $dest.FullName 'MyController.js') | should contain 'MyController'
        (Join-Path $dest.FullName 'MyController.js') | should not contain '$safeitemname$'
        
        (Get-ChildItem $dest.FullName).Count | should be 1
    }

    It 'can run demo-angularfiles item'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'angularfiles')
        Ensure-PathExists -path $dest.FullName

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

Describe 'template source tests'{
    . $importPecanWaffle
    BeforeEach{
        Clear-AllTemplates
    }
    
    It 'can find templates locally' {
        $numTemplatesBefore = ($Global:pecanwafflesettings.Templates.Count)

        Add-TemplateSource -path (Join-Path $sourceRoot 'templates\samples')

        $numTemplatesAfter = ($Global:pecanwafflesettings.Templates.Count)

        $numTemplatesAfter -gt $numTemplatesBefore | should be $true
    }

    It 'can add from git (may fail if there are breaking changes in local but not remote)'{
        $url = 'https://github.com/ligershark/pecan-waffle.git'

        $numTemplatesBefore = ($Global:pecanwafflesettings.Templates.Count)

        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'angularfiles')
        Ensure-PathExists -path $dest.FullName
        Add-TemplateSource -url $url -localfolder $dest.FullName

        $numTemplatesAfter = ($Global:pecanwafflesettings.Templates.Count)

        $numTemplatesAfter -gt $numTemplatesBefore | should be $true
    }
}

Describe 'git tests'{
    It 'can clone from github w/o repo name'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'github01')
        Ensure-PathExists -path $dest.FullName

        $repoName = 'pecan-waffle'
        {InternalAdd-GitFolder -url 'https://github.com/ligershark/pecan-waffle.git' -localfolder $dest.FullName} | should not throw
        $dest.FullName | should exist
        (Join-Path $dest.FullName "$repoName\readme.md") | should exist
    }

    It 'can clone from github with repo name'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'github02')
        Ensure-PathExists -path $dest.FullName

        $repoName = 'pecan-waffle'
        {InternalAdd-GitFolder -url 'https://github.com/ligershark/pecan-waffle.git' -repoName $repoName -localfolder $dest.FullName} | should not throw
        $dest.FullName | should exist
        (Join-Path $dest.FullName "$repoName\readme.md") | should exist
    }

    It 'can clone from github with repo name and branch'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'github03')
        Ensure-PathExists -path $dest.FullName

        $repoName = 'pecan-waffle'
        $branch = 'dev'
        {InternalAdd-GitFolder -url 'https://github.com/ligershark/pecan-waffle.git' -repoName $repoName -branch $branch -localfolder $dest.FullName } | should not throw
        $dest.FullName | should exist
        (Join-Path $dest.FullName "$repoName\readme.md") | should exist
    }
}

Describe 'get repo name tests'{
    It 'can get repo name from url'{
        # InternalGet-RepoName
        $url = 'https://github.com/ligershark/pecan-waffle.git'
        $repoName = InternalGet-RepoName -url $url

        $repoName | should be 'pecan-waffle'
    }
}

Describe 'misc tests'{
    . $importPecanWaffle

    It 'can call show-templates'{
        $result = Show-Templates
        $result | should not be $null
    }
}

