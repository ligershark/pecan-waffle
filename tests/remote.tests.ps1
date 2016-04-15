[cmdletbinding()]
param()

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}
$scriptDir = ((Get-ScriptDirectory) + "\")

$importPecanWaffle = (Join-Path -Path $scriptDir -ChildPath 'import-pw.ps1')

# import the module
. $importPecanWaffle

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

Describe 'handle-install-project.ps1 tests'{
    BeforeEach{
        Remove-Module pecan-waffle -Force
    }

    [string]$handleInstallFile = (get-item (Join-Path $scriptDir '..\vs-src\PecanWaffleVs\handle-install-project.ps1')).FullName
    It 'can run handle install file'{
        $templatePath = (get-item (Join-Path $scriptDir '..\templates')).FullName
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'hinstall01')
        Ensure-PathExists -path $dest.FullName

        { & $handleInstallFile -templateName aspnet5-empty -projectname myproj -destpath $dest.FullName -pwInstallBranch dev -templateSource $templatePath} | Should not throw
        "$dest\project.json" | should exist
        "$dest\startup.cs" | should exist
    }
}