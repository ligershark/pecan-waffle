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
# import the module
. $importPecanWaffle

[System.IO.DirectoryInfo]$sourceRoot = (Join-Path $scriptDir '..\')

Describe 'add project tests'{
    It 'can run aspnet5-empty project'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'empty01')
        Ensure-PathExists -path $dest.FullName

        { New-PWProject -templateName 'aspnet5-empty' -destPath $dest.FullName -projectName 'MyNewEmptyProj' -noNewFolder } |should not throw

        (Join-Path $dest.FullName 'MyNewEmptyProj.xproj') | should exist
        (Join-Path $dest.FullName 'project.json') | should exist
        (Join-Path $dest.FullName 'project.lock.json') | should not exist

        (Join-Path $dest.FullName 'MyNewEmptyProj.xproj') | should contain 'MyNewEmptyProj'
        (Join-Path $dest.FullName 'MyNewEmptyProj.xproj') | should not contain 'EmptyProject'
    }

    It 'can run demo-singlefileproj project'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'singlefileproj')
        Ensure-PathExists -path $dest.FullName

        { New-PWProject -templateName 'demo-singlefileproj' -destPath $dest.FullName -projectName 'DemoProjSingleItem' -noNewFolder } |should not throw
        (Get-ChildItem -Path $dest.FullName -File).Count | should be 1
        (Join-Path $dest.FullName 'DemoProjSingleItem.xproj') | should exist

        (Join-Path $dest.FullName 'DemoProjSingleItem.xproj') | should contain 'DemoProjSingleItem'
       (Join-Path $dest.FullName 'DemoProjSingleItem.xproj') | should not contain '$safeitemname$'
    }

    It 'can run aspnet5-webapi project'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'webapi')
        Ensure-PathExists -path $dest.FullName

        { New-PWProject -templateName 'aspnet5-webapi' -destPath $dest.FullName -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        (Join-Path $dest.FullName 'MyNewApiProj.xproj') | should exist
        (Join-Path $dest.FullName 'project.json') | should exist
        (Join-Path $dest.FullName 'project.lock.json') | should not exist

        (Join-Path $dest.FullName 'MyNewApiProj.xproj') | should contain 'MyNewApiProj'
        (Join-Path $dest.FullName 'MyNewApiProj.xproj') | should not contain 'WebApiProject'
    }

    It 'will run beforeinstall' {
        # remove all templates
        Clear-PWTemplates

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

        { New-PWProject -templateName 'demo01' -destPath $dest.FullName -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        $Global:pwtestcount | should be 1
    }

    It 'will run afterinstall' {
        # remove all templates
        Clear-PWTemplates

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

        { New-PWProject -templateName 'demo01' -destPath $dest.FullName -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        $Global:pwtestcount | should be 1
    }

    It 'will run both before and after install'{
        # remove all templates
        Clear-PWTemplates

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

        { New-PWProject -templateName 'demo01' -destPath $dest.FullName -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        $Global:pwtestcount | should be 2
    }

    It 'will run both before and after install in order'{
        # remove all templates
        Clear-PWTemplates

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

        { New-PWProject -templateName 'demo01' -destPath $dest.FullName -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        $Global:pwtestbeforestart.CompareTo($Global:pwtestafterstart) | Should be -1
    }

    It 'can accept properties via New-PWProject 01'{
        Clear-PWTemplates

        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'demo01'
            Type = 'ProjectTemplate'
            DefaultProjectName = 'DefaultProject'
        }

        $templateInfo | replace (
            ,('EmptyProject', {"$ProjectName"}, {"$DefaultProjectName"})
        )

        $templateInfo | update-filename (
            ,('EmptyProject', {"$ProjectName"})
        )

        [System.IO.DirectoryInfo]$emptyTemplatePath =(Join-Path $sourceRoot 'templates\aspnet5\EmptyProject')
        Set-TemplateInfo -templateInfo $templateInfo -templateRoot $emptyTemplatePath.FullName

        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'newproj-props01')
        Ensure-PathExists -path $dest.FullName

        { New-PWProject -templateName 'demo01' -destPath $dest.FullName -properties @{'projectName'='MyNewApiProj'} -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        ([System.IO.FileInfo](Join-Path $dest.FullName 'MyNewApiProj.xproj')).FullName | should exist
    }

    It 'project name will override properties'{
        Clear-PWTemplates

        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'demo01'
            Type = 'ProjectTemplate'
            DefaultProjectName = 'DefaultProject'
        }

        $templateInfo | replace (
            ,('EmptyProject', {"$ProjectName"}, {"$DefaultProjectName"})
        )

        $templateInfo | update-filename (
            ,('EmptyProject', {"$ProjectName"})
        )

        [System.IO.DirectoryInfo]$emptyTemplatePath =(Join-Path $sourceRoot 'templates\aspnet5\EmptyProject')
        Set-TemplateInfo -templateInfo $templateInfo -templateRoot $emptyTemplatePath.FullName

        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'projname-overrides-props')
        Ensure-PathExists -path $dest.FullName

        { New-PWProject -templateName 'demo01' -destPath $dest.FullName -properties @{'projectName'='MyNewApiProj'} -projectName 'MyRealProjectName' -noNewFolder} |should not throw

        ([System.IO.FileInfo](Join-Path $dest.FullName 'MyRealProjectName.xproj')).FullName | should exist
        ([System.IO.FileInfo](Join-Path $dest.FullName 'MyNewApiProj.xproj')).FullName | should not exist
    }
}

Describe 'add item tests'{
    . $importPecanWaffle

    It 'can run demo-controllerjs item'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'controllerjs')
        if(-not (Test-Path $dest.FullName)){
            New-Item -Path $dest.FullName -ItemType Directory
        }

        { New-PWItem -templateName 'demo-controllerjs' -destPath $dest.FullName -itemName 'MyController' } | should not throw
        
        (Join-Path $dest.FullName 'MyController.js') | should exist
        (Join-Path $dest.FullName 'directive.js') | should not exist
        
        (Join-Path $dest.FullName 'MyController.js') | should contain 'MyController'
        (Join-Path $dest.FullName 'MyController.js') | should not contain '$safeitemname$'
        
        (Get-ChildItem $dest.FullName).Count | should be 1
    }

    It 'can run demo-angularfiles item'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'angularfiles')
        Ensure-PathExists -path $dest.FullName

        { New-PWItem -templateName 'demo-angularfiles' -destPath $dest.FullName -itemName 'angular' } | should not throw
        
        (Join-Path $dest.FullName 'controller.js') | should exist
        (Join-Path $dest.FullName 'directive.js') | should exist
        
        (Join-Path $dest.FullName 'controller.js') | should contain 'angular'
        (Join-Path $dest.FullName 'controller.js') | should not contain '$safeitemname$'
        $countTemplateFiles = (Get-ChildItem (Join-Path $scriptDir '..\templates\samples\item-templates\') -Exclude 'pw-templ*').Count
        $countDestFiles = (Get-ChildItem $dest.FullName).Count
        $countDestFiles | should be $countTemplateFiles
    }

    It 'can get item name from properties'{
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'item-name-from-props')
        if(-not (Test-Path $dest.FullName)){
            New-Item -Path $dest.FullName -ItemType Directory
        }

        { New-PWItem -templateName 'demo-controllerjs' -destPath $dest.FullName -properties @{'ItemName'='MyController'} } | should not throw

        (Join-Path $dest.FullName 'MyController.js') | should exist
        (Join-Path $dest.FullName 'directive.js') | should not exist

        (Join-Path $dest.FullName 'MyController.js') | should contain 'MyController'
        (Join-Path $dest.FullName 'MyController.js') | should not contain '$safeitemname$'

        (Get-ChildItem $dest.FullName).Count | should be 1
    }
}

Describe 'template source tests'{
    . $importPecanWaffle    BeforeEach{
        Clear-PWTemplates
    }
    
    It 'can find templates locally' {
        $numTemplatesBefore = ($Global:pecanwafflesettings.Templates.Count)

        Add-PWTemplateSource -path (Join-Path $sourceRoot 'templates\samples')

        $numTemplatesAfter = ($Global:pecanwafflesettings.Templates.Count)

        $numTemplatesAfter -gt $numTemplatesBefore | should be $true
    }

    It 'can add from git (may fail if there are breaking changes in local but not remote)'{
        $url = 'https://github.com/ligershark/pecan-waffle.git'

        $numTemplatesBefore = ($Global:pecanwafflesettings.Templates.Count)

        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'angularfiles')
        Ensure-PathExists -path $dest.FullName
        Add-PWTemplateSource -path $url -localfolder $dest.FullName

        $numTemplatesAfter = ($Global:pecanwafflesettings.Templates.Count)

        $numTemplatesAfter -gt $numTemplatesBefore | should be $true
    }
}

Describe 'InternalGet-EvaluatedProperty tests' {
    It 'can eval from string'{
        $expectedvalue = 'some value'
        $result = InternalGet-EvaluatedProperty -expression {"some value"}
        $result | should be $expectedvalue
    }

    It 'can get from $p'{
        $expectedvalue = 'some value'
        $result = InternalGet-EvaluatedProperty -expression {$p['MyProp']} -properties @{'MyProp'=$expectedvalue}
        $result | should be $expectedvalue
    }

    It 'will return null if the property is not passed'{
        $expectedvalue = 'some value'
        $result = InternalGet-EvaluatedProperty -expression {$p['MyProp222']} -properties @{'MyProp'=$expectedvalue}
        $result | should be $null
    }

    It 'can get from $p via extraProperties'{
        $expectedvalue = 'some value'
        $result = InternalGet-EvaluatedProperty -expression {$p['MyProp2']} -properties @{'MyProp'='ignored'} -extraProperties @{'MyProp2'=$expectedvalue}
        $result | should be $expectedvalue
    }

    # todo: do we want users to go through $p?
    It 'can get via extraProperties'{
        $expectedvalue = 'some value'
        $result = InternalGet-EvaluatedProperty -expression {$MyProp2} -properties @{'MyProp'='ignored'} -extraProperties @{'MyProp2'=$expectedvalue}
        $result | should be $expectedvalue
    }

    It 'will get from extraProperties instead of properties when both exist'{
        $expectedvalue = 'some value'
        $result = InternalGet-EvaluatedProperty -expression {$MyProp} -properties @{'MyProp'='ignored'} -extraProperties @{'MyProp'=$expectedvalue}
        $result | should be $expectedvalue
    }

    It 'can evaluate expressions 01'{
        [System.Guid]$result = InternalGet-EvaluatedProperty -expression {[System.Guid]::NewGuid()}
        $result | should not be null
        $result.Guid | should not be ([System.Guid]::Empty)
    }

    It 'can evaluate expressions with properties'{
        $result = InternalGet-EvaluatedProperty -expression {$Name + $Extension} -properties @{'Name'='controller';'Extension'='.js'}
        $result | should be 'controller.js'
    }

    It 'can evaluate expressions with properties and ex properties'{
        $result = InternalGet-EvaluatedProperty -expression {$Name + $Extension} -properties @{'Name'='controller'} -extraProperties @{'Extension'='.js'}
        $result | should be 'controller.js'
    }

    # todo: maybe we should disable this somehow?
    It 'can get from global var'{
        $global:expectedvalue1 = 'some value'
        $result = InternalGet-EvaluatedProperty -expression {"$global:expectedvalue1"}
        $result | should be $global:expectedvalue1
    }
}

Describe 'InternalGet-ReplacementValue tests'{
    It 'can get via hard coded string'{
        Clear-PWTemplates
        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'template-name-here'
            Type = 'ProjectTemplate'
        }

        $templateInfo | replace (
            ,('EmptyProject', {"demo01"})
        )

        Set-TemplateInfo -templateInfo $templateInfo
        $templateObj = ($Global:pecanwafflesettings.Templates|Where-Object {$_.Type -eq 'ProjectTemplate' -and $_.Name -eq 'template-name-here'}|Select-Object -First 1)

        $result = InternalGet-ReplacementValue -template $templateObj -replaceKey 'EmptyProject'
        $result | should be 'demo01'
    }

    It 'can get via hard coded string in default'{
        Clear-PWTemplates
        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'template-name-here'
            Type = 'ProjectTemplate'
        }

        $templateInfo | replace (
            ,('EmptyProject', {$null}, {"demo02"})
        )

        Set-TemplateInfo -templateInfo $templateInfo
        $templateObj = ($Global:pecanwafflesettings.Templates|Where-Object {$_.Type -eq 'ProjectTemplate' -and $_.Name -eq 'template-name-here'}|Select-Object -First 1)

        $result = InternalGet-ReplacementValue -template $templateObj -replaceKey 'EmptyProject'
        $result | should be 'demo02'
    }

    It 'can get properties and $p'{
        Clear-PWTemplates
        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'template-name-here'
            Type = 'ProjectTemplate'
        }

        $templateInfo | replace (
            ,('EmptyProject', {$p['SomeProp']})
        )

        Set-TemplateInfo -templateInfo $templateInfo
        $templateObj = ($Global:pecanwafflesettings.Templates|Where-Object {$_.Type -eq 'ProjectTemplate' -and $_.Name -eq 'template-name-here'}|Select-Object -First 1)

        $result = InternalGet-ReplacementValue -template $templateObj -replaceKey 'EmptyProject' -evaluatedProperties @{'SomeProp'='value here'}
        $result | should be 'value here'
    }

    It 'can get properties and w/o $p'{
        Clear-PWTemplates
        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'template-name-here'
            Type = 'ProjectTemplate'
        }

        $templateInfo | replace (
            ,('EmptyProject', {$SomeProp})
        )

        Set-TemplateInfo -templateInfo $templateInfo
        $templateObj = ($Global:pecanwafflesettings.Templates|Where-Object {$_.Type -eq 'ProjectTemplate' -and $_.Name -eq 'template-name-here'}|Select-Object -First 1)

        $result = InternalGet-ReplacementValue -template $templateObj -replaceKey 'EmptyProject' -evaluatedProperties @{'SomeProp'='value here'}
        $result | should be 'value here'
    }
}

Describe 'InternalGet-EvaluatedPropertiesFrom tests'{
    It 'can get from value from template property 01'{
        Clear-PWTemplates
        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'template-name-here'
            Type = 'ProjectTemplate'
        }

        $templateInfo | replace (
            ,('EmptyProject', {$Name})
        )

        Set-TemplateInfo -templateInfo $templateInfo
        $templateObj = ($Global:pecanwafflesettings.Templates|Where-Object {$_.Type -eq 'ProjectTemplate' -and $_.Name -eq 'template-name-here'}|Select-Object -First 1)

        $allprops = InternalGet-EvaluatedPropertiesFrom -template $templateObj
        $result = $allprops['EmptyProject']
        $result | should be 'template-name-here'
    }

    It 'can get from value from template property 02'{
        Clear-PWTemplates
        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'template-name-here'
            Type = 'ProjectTemplate'
            SomeOtherProp = 'some other value'
        }

        $templateInfo | replace (
            ,('EmptyProject', {$SomeOtherProp})
        )

        Set-TemplateInfo -templateInfo $templateInfo
        $templateObj = ($Global:pecanwafflesettings.Templates|Where-Object {$_.Type -eq 'ProjectTemplate' -and $_.Name -eq 'template-name-here'}|Select-Object -First 1)

        $allprops = InternalGet-EvaluatedPropertiesFrom -template $templateObj
        $result = $allprops['EmptyProject']
        $result | should be 'some other value'
    }

    It 'can get from value from template property via default'{
        Clear-PWTemplates
        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'template-name-here'
            Type = 'ProjectTemplate'
            SomeOtherProp = 'some other value'
        }

        $templateInfo | replace (
            ,('EmptyProject',{$null}, {$SomeOtherProp})
        )

        Set-TemplateInfo -templateInfo $templateInfo
        $templateObj = ($Global:pecanwafflesettings.Templates|Where-Object {$_.Type -eq 'ProjectTemplate' -and $_.Name -eq 'template-name-here'}|Select-Object -First 1)

        $allprops = InternalGet-EvaluatedPropertiesFrom -template $templateObj
        $result = $allprops['EmptyProject']
        $result | should be 'some other value'
    }
}

Describe 'exclude tests'{
    . $importPecanWaffle
    It 'can exclude a specific file'{
        [System.IO.DirectoryInfo]$templateSource = (Join-Path $TestDrive 'exclude01\src')
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'exclude01\dest')
        Ensure-PathExists -path $templateSource.FullName
        Ensure-PathExists -path $dest.FullName

        Create-TestFileAt -path (Join-Path $templateSource.FullName 'appsettings.json')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'project.json')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'Startup.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'WebApiProject.xproj')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'otherfile.json')

        # remove all templates
        Clear-PWTemplates

        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'exclude01'
            Type = 'ProjectTemplate'
        }

        $templateInfo | exclude-file 'otherfile.json'

        Set-TemplateInfo -templateInfo $templateInfo -templateRoot $templateSource.FullName

        { New-PWProject -templateName 'exclude01' -destPath $dest.FullName -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        $destFull = $dest.FullName
        "$destFull\appsettings.json" | should exist
        "$destFull\project.json" | should exist
        "$destFull\Startup.cs" | should exist
        "$destFull\WebApiProject.xproj" | should exist
        "$destFull\otherfile.json" | should not exist
    }

    It 'can exclude multiple files by pattern'{
        [System.IO.DirectoryInfo]$templateSource = (Join-Path $TestDrive 'exclude02\src')
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'exclude02\dest')
        Ensure-PathExists -path $templateSource.FullName
        Ensure-PathExists -path $dest.FullName

        Create-TestFileAt -path (Join-Path $templateSource.FullName 'appsettings.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'project.json')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'Startup.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'WebApiProject.xproj')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'otherfile.cs')

        # remove all templates
        Clear-PWTemplates

        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'exclude02'
            Type = 'ProjectTemplate'
        }

        $templateInfo | exclude-file '*.cs'

        Set-TemplateInfo -templateInfo $templateInfo -templateRoot $templateSource.FullName

        { New-PWProject -templateName 'exclude02' -destPath $dest.FullName -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        $destFull = $dest.FullName
        (Get-ChildItem -Path $destFull).Length | should be 2
        "$destFull\appsettings.cs" | should not exist
        "$destFull\project.json" | should exist
        "$destFull\Startup.cs" | should not exist
        "$destFull\WebApiProject.xproj" | should exist
        "$destFull\otherfile.cs" | should not exist
    }

    It 'can exclude a single folder'{
        [System.IO.DirectoryInfo]$templateSource = (Join-Path $TestDrive 'exclude03\src')
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'exclude03\dest')
        Ensure-PathExists -path $templateSource.FullName
        Ensure-PathExists -path $dest.FullName

        # root dir
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'appsettings.json')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'project.json')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'Startup.json')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'WebApiProject.json')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'otherfile.json')
        # artifacts folder
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts\01.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts\02.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts\other\01.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts\other\02.cs')
        # models folder
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'models\01.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'models\person\01.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'models\02.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'models\other\01.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'models\03.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'models\04.cs')

        # remove all templates
        Clear-PWTemplates

        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'exclude03'
            Type = 'ProjectTemplate'
        }

        $templateInfo | exclude-folder 'artifacts'

        Set-TemplateInfo -templateInfo $templateInfo -templateRoot $templateSource.FullName

        { New-PWProject -templateName 'exclude03' -destPath $dest.FullName -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        $destFull = $dest.FullName
        "$destFull" | Write-output
        "$destFull\appsettings.json" | should exist
        "$destFull\artifacts" | should not exist
        "$destFull\models\" | should exist
        "$destFull\models\person" | should exist
        (Get-ChildItem -Path "$destFull" '*.json' -File).Length | should be 5
        (Get-ChildItem -Path "$destFull\models" '*.cs' -Recurse -File).Length | should be 6
    }

    It 'can exclude a multiple folders'{
        [System.IO.DirectoryInfo]$templateSource = (Join-Path $TestDrive 'exclude04\src')
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'exclude04\dest')
        Ensure-PathExists -path $templateSource.FullName
        Ensure-PathExists -path $dest.FullName

        # root dir
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'appsettings.json')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'project.json')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'Startup.json')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'WebApiProject.json')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'otherfile.json')
        # artifacts folder
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts\01.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts\02.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts\other\01.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts\other\02.cs')
        # models folder
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'models\01.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'models\person\01.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'models\02.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'models\other\01.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'models\03.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'models\04.cs')

        # remove all templates
        Clear-PWTemplates

        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'exclude04'
            Type = 'ProjectTemplate'
        }

        $templateInfo | exclude-folder 'artifacts','models'

        Set-TemplateInfo -templateInfo $templateInfo -templateRoot $templateSource.FullName

        { New-PWProject -templateName 'exclude04' -destPath $dest.FullName -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        $destFull = $dest.FullName
        "$destFull" | Write-output
        "$destFull\appsettings.json" | should exist
        "$destFull\artifacts" | should not exist
        "$destFull\models\" | should not exist
        (Get-ChildItem -Path "$destFull" '*.json' -File).Length | should be 5
    }

    It 'can exclude a multiple folders by pattern'{
        [System.IO.DirectoryInfo]$templateSource = (Join-Path $TestDrive 'exclude05\src')
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'exclude05\dest')
        Ensure-PathExists -path $templateSource.FullName
        Ensure-PathExists -path $dest.FullName

        # root dir
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'appsettings.json')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'project.json')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'Startup.json')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'WebApiProject.json')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'otherfile.json')
        # artifacts folder
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts\01.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts\02.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts\other\01.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts\other\02.cs')
        # models folder
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts2\01.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts2\person\01.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts2\02.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts2\other\01.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts2\03.cs')
        Create-TestFileAt -path (Join-Path $templateSource.FullName 'artifacts2\04.cs')

        # remove all templates
        Clear-PWTemplates

        $templateInfo = New-Object -TypeName psobject -Property @{
            Name = 'exclude05'
            Type = 'ProjectTemplate'
        }

        $templateInfo | exclude-folder 'artifacts*'

        Set-TemplateInfo -templateInfo $templateInfo -templateRoot $templateSource.FullName

        { New-PWProject -templateName 'exclude05' -destPath $dest.FullName -projectName 'MyNewApiProj' -noNewFolder} |should not throw

        $destFull = $dest.FullName
        "$destFull" | Write-output
        "$destFull\appsettings.json" | should exist
        "$destFull\artifacts" | should not exist
        "$destFull\artifacts2\" | should not exist
        (Get-ChildItem -Path "$destFull" '*.json' -File).Length | should be 5
    }
}

Describe 'misc tests'{
    . $importPecanWaffle

    It 'can call show-templates'{
        $result = Show-Templates
        $result | should not be $null
    }
}