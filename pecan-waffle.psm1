[cmdletbinding()]
param(
    $nugetPsMinModuleVersion = '0.2.1.1'
)

$global:pecanwafflesettings = New-Object -TypeName psobject -Property @{
    TempDir = [System.IO.DirectoryInfo]('{0}\pecan-waffle\temp\projtemplates' -f $env:LOCALAPPDATA)
    Templates = @()
}

function Get-ValueOrDefault{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [object]$value,

        [Parameter(Position=1, Mandatory=$true)]
        [ValidateNotNull()]
        [object]$defaultValue
    )
    process{
        if($value -ne $null){
            $value
        }
        else{
            $defaultValue
        }
    }
}

function Internal-HasProperty{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNull()]
        $inputObject,

        [Parameter(Position=1,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$propertyName
    )
    process{
        [bool]($inputObject.PSObject.Properties.name -match ('^{0}$' -f $propertyName))
    }
}

function Internal-AddProperty{
    [cmdletbinding()]
    param(
        [Parameter(Position=1,Mandatory=$true)]
        [ValidateNotNull()]
        $inputObject,

        [Parameter(Position=2,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$propertyName,

        [Parameter(Position=3,Mandatory=$true)]
        $propertyValue
    )
    process{
        $inputObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value $propertyValue
    }
}

function InternalGet-NewTempDir{
    [cmdletbinding()]
    param()
    process{
        if(-not (Test-Path $global:pecanwafflesettings.TempDir)){
            New-Item -ItemType Directory -Path ($global:pecanwafflesettings.TempDir.FullName) | Out-Null
        }

        [System.IO.DirectoryInfo]$newpath = Join-Path ($global:pecanwafflesettings.TempDir.FullName) ([System.Guid]::NewGuid())
        New-Item -ItemType Directory -Path $newpath.FullName | out-null
        # return the fullpath
        $newpath.FullName
    }
}

function Add-Replacement{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        $templateInfo,

        [Parameter(Position=1,Mandatory=$true)]
        [string]$replaceKey,

        [Parameter(Position=2,Mandatory=$true)]
        [ScriptBlock]$replaceValue,

        [Parameter(Position=3)]
        [ScriptBlock]$defaultValue,

        [Parameter(Position=4)]
        [string]$rootDir,

        [Parameter(Position=5)]
        [string[]]$include = @('*'),

        [Parameter(Position=6)]
        [string[]]$exclude
    )
    process{
        # make sure it has the properties member, if not add it
        if(-not (Internal-HasProperty -inputObject $templateInfo -propertyName 'Replacements')){
            Internal-AddProperty -inputObject $templateInfo -propertyName 'Replacements' -propertyValue @()
        }
        
        $templateInfo.Replacements += New-Object -TypeName psobject -Property @{
            ReplaceKey = $replaceKey
            ReplaceValue = $replaceValue
            DefaultValue = $defaultValue
            RootDir = $rootDir
            Include = $include
            Exclude = $exclude
        }
    }
}

function Update-FileName{
    [cmdletbinding()]
    param(
        [Parameter(Position=1,Mandatory=$true)]
        $templateInfo,

        [Parameter(Position=2,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$replaceKey,

        [Parameter(Position=3,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ScriptBlock]$replaceValue
    )
    process{
        if(-not (Internal-HasProperty -inputObject $templateInfo -propertyName 'UpdateFilenames')){
            Internal-AddProperty -inputObject $templateInfo -propertyName 'UpdateFilenames' -propertyValue @()
        }

        $templateInfo.UpdateFilenames += New-Object -TypeName psobject -Property @{
            ReplaceKey = $replaceKey
            ReplaceValue = $replaceValue
        }
    }
}

function Before-Install{
    [cmdletbinding()]
    param(
        [Parameter(Position=1,Mandatory=$true)]
        $templateInfo,
        [Parameter(Position=2,Mandatory=$true)]
        [ScriptBlock]$beforeInstall
    )
    process{
        if(-not (Internal-HasProperty -inputObject $templateInfo -propertyName 'BeforeInstall')){
            Internal-AddProperty -inputObject $templateInfo -propertyName 'BeforeInstall' -propertyValue $beforeInstall
        }
        else{
            $templateInfo.BeforeInstall = $beforeInstall
        }
    }
}

function After-Install{
    [cmdletbinding()]
    param(
        [Parameter(Position=1,Mandatory=$true)]
        $templateInfo,
        [Parameter(Position=2,Mandatory=$true)]
        [ScriptBlock]$afterInstall
    )
    process{
        if(-not (Internal-HasProperty -inputObject $templateInfo -propertyName 'AfterInstall')){
            Internal-AddProperty -inputObject $templateInfo -propertyName 'AfterInstall' -propertyValue $afterInstall
        }
        else{
            $templateInfo.AfterInstall = $afterInstall
        }
    }
}

function Exclude-File{
    [cmdletbinding()]
    param(
        [Parameter(Position=1,Mandatory=$true)]
        $templateInfo,

        [Parameter(Position=2,Mandatory=$true)]
        [ValidateNotNull()]
        [string[]]$excludeFiles
    )
    process{
        if(-not (Internal-HasProperty -inputObject $templateInfo -propertyName 'ExcludeFiles')){
            Internal-AddProperty -inputObject $templateInfo -propertyName 'ExcludeFiles' -propertyValue @()
        }

        $templateInfo.ExcludeFiles += $excludeFiles
    }
}

function Exclude-Folder{
    [cmdletbinding()]
    param(
        [Parameter(Position=1,Mandatory=$true)]
        $templateInfo,

        [Parameter(Position=2,Mandatory=$true)]
        [ValidateNotNull()]
        [string[]]$excludeFolder
    )
    process{
        if(-not (Internal-HasProperty -inputObject $templateInfo -propertyName 'ExcludeFolder')){
            Internal-AddProperty -inputObject $templateInfo -propertyName 'ExcludeFolder' -propertyValue @()
        }

        $templateInfo.ExcludeFolder += $excludeFolder
    }
}

function Set-TemplateInfo{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNull()]
        $templateInfo
    )
    process{
        if(-not (Internal-HasProperty -inputObject $templateInfo -propertyName 'TemplatePath')){
            # $MyInvocation.PSCommandPath
            Internal-AddProperty -inputObject $templateInfo -propertyName 'TemplatePath' -propertyValue @()
            $templateInfo.TemplatePath = ((Get-Item ($MyInvocation.PSCommandPath)).Directory.FullName)
        }

        $global:pecanwafflesettings.Templates += $templateInfo        
    }
}

function InternalGet-EvaluatedProperty{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ScriptBlock]$expression,

        [Parameter(Position=1,Mandatory=$true)]
        [hashtable]$properties
    )
    process{
        $scriptToExec = [ScriptBlock]::Create({$fargs=$args; foreach($f in $fargs.Keys){ New-Variable -Name $f -Value $fargs.$f };}.ToString() + $expression.ToString())
        $value = & ($scriptToExec) $evaluatedProps

        # return the value
        $value
    }
}

function Add-Project{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [string]$templateName,

        [Parameter(Position=1)]
        [System.IO.DirectoryInfo]$destPath,

        [Parameter(Position=2)]
        [string]$projectName = 'MyNewProject'
    )
    process{
        # find the project template with the given name
        $template = ($Global:pecanwafflesettings.Templates|Where-Object {$_.Type -eq 'ProjectTemplate' -and $_.Name -eq $templateName}|Select-Object -First 1)

        if($template -eq $null){
            throw ('Did not find a template with the name [{0}]' -f $templateName)
        }

        [System.IO.DirectoryInfo]$tempWorkDir = InternalGet-NewTempDir
        [string]$sourcePath = $template.TemplatePath
        
        try{
            # copy all of the files besides those that start with pw- to the temp directory
            'Copying template files from [{0}] to [{1}]' -f $template.TemplatePath,$tempWorkDir.FullName | Write-Verbose
            Copy-Item -Path $sourcePath\* -Destination $tempWorkDir.FullName -Recurse -Include * -Exclude ($template.ExcludeFiles)

            # remove directories in the exclude list
            if($template.ExcludeFolder -ne $null){
                Get-ChildItem -Path $tempWorkDir.FullName -Include $template.ExcludeFolder -Recurse -Directory | Remove-Item -Recurse -ErrorAction SilentlyContinue
            }

            # eval properties here
            $evaluatedProps = @{}
            $evaluatedProps['templateWorkingDir'] = $tempWorkDir.FullName
            # add all the properties of $template into evaluatedProps
            foreach($name in $template.psobject.Properties.Name){
                $evaluatedProps[$name]=($template.$name)
            }
            
            if($template.Replacements -ne $null){
                foreach($rep in $template.Replacements){
                    # $scriptToExec = [ScriptBlock]::Create({$fargs=$args; foreach($f in $fargs.Keys){ New-Variable -Name $f -Value $fargs.$f };}.ToString() + $rep.ReplaceValue.ToString())
                    # $value = & ($scriptToExec) $evaluatedProps

                    $evaluatedProps[$rep.ReplaceKey] = InternalGet-EvaluatedProperty -expression $rep.ReplaceValue -properties $evaluatedProps
                }
            }
            
            # replace file names
            $template.UpdateFilenames | ForEach-Object { 
                $current = $_
                [System.IO.FileInfo[]]$files = (Get-ChildItem $tempWorkDir.FullName ('*{0}*' -f $current.ReplaceKey) -Recurse)
                foreach($file in $files){
                    $file = [System.IO.FileInfo]$file
                    $repvalue = InternalGet-EvaluatedProperty -expression $current.ReplaceValue -properties $evaluatedProps
                    $newname = $file.Name.Replace($current.ReplaceKey,$repvalue)
                    [System.IO.FileInfo]$newpath = (Join-Path ($file.Directory.FullName) $newname)
                    Move-Item $file.FullName $newpath.FullName
                }
            }

            if($template.BeforeInstall -ne $null){
                InternalGet-EvaluatedProperty -expression $template.BeforeInstall -properties $evaluatedProps
            }

            # replace content in files
            if(-not (Test-Path $destPath.FullName)){
                New-Item -Path $destPath.FullName -ItemType Directory
            }
            [string]$tpath = $tempWorkDir.FullName
            # copy the final result to the destination
            Copy-Item $tpath\* -Destination $destPath.FullName -Recurse -Include *

            if($template.AfterInstall -ne $null){
                InternalGet-EvaluatedProperty -expression $template.AfterInstall -properties $evaluatedProps
            }
        }
        finally{
            # delete the temp dir and ignore any errors
            if(Test-Path $tempWorkDir.FullName){
                Remove-Item $tempWorkDir.FullName -Recurse -ErrorAction SilentlyContinue
            }
        }
    }
}

# TODO: Update this later
Export-ModuleMember -function * -Alias *













