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

# Items related to template sources

function Add-TemplateSource{
    [cmdletbinding(DefaultParameterSetName='local')]
    param(
        [Parameter(Position=0,Mandatory=$true,ParameterSetName='local')]
        [System.IO.DirectoryInfo]$path,

        [Parameter(Position=0,Mandatory=$true,ParameterSetName='git')]
        [ValidateNotNullOrEmpty()]
        [string]$url,

        [Parameter(Position=1,ParameterSetName='git')]
        $branch = 'master',

        [Parameter(Position=2,ParameterSetName='git')]
        [System.IO.DirectoryInfo]$localfolder = ('{0}\pecan-waffle\remote\templates' -f $env:LOCALAPPDATA),

        [Parameter(Position=3,ParameterSetName='git')]
        [string]$repoName
    )
    process{
        [string]$localpath = $null
        if($path -ne $null){
            [string]$localpath = $path.FullName
        }
        else{
            if(-not (Test-Path $localfolder)){
                New-Item -Path $localfolder.FullName -ItemType Directory
            }

            $oldPath = Get-Location

            if([string]::IsNullOrWhiteSpace($repoName)){
                $startIndex = $url.LastIndexOf('/')
                [string]$repoName = [System.Guid]::NewGuid()
                if($startIndex -gt 0){
                    $repoName = $url.Substring($startIndex +1).Replace('.git','')
                }
            }

            try{
                Set-Location $localfolder
                $destFolder = (Join-Path $localfolder.FullName $repoName)

                if(-not (Test-Path $destFolder)){
                    Execute-CommandString "git clone $url --branch $branch --single-branch $repoName"
                }
            }
            finally{
                Set-Location $oldPath
            }
        }

        $files = (Get-ChildItem -Path $path 'pw-templateinfo.ps1' -Recurse -File)
        foreach($file in $files){
            & ([System.IO.FileInfo]$file.FullName)
        }
    }
}

# Template Related Functions Below

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

function InternalGet-ReplacementValue{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNull()]
        $template,

        [Parameter(Position=1,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$replaceKey,

        [Parameter(Position=2,Mandatory=$true)]
        [ValidateNotNull()]
        [hashtable]$evaluatedProperties
    )
    process{
        $replacement = ($template.Replacements| Where-Object {$_.ReplaceKey -eq $replaceKey} | Select-Object -First 1)
        if($replacement -eq $null){
            throw ('Did not find replacement with key [{0}]' -f $replaceKey)
        }

        $value = InternalGet-EvaluatedProperty -expression $replacement.ReplaceValue -properties $evaluatedProperties

        if( ($value -eq $null) -or
            ($value -is [string] -and ([string]::IsNullOrWhiteSpace($value) ) ) ) {

            if( ($replacement -ne $null) -and ($replacement.DefaultValue -ne $null)){
                $value = InternalGet-EvaluatedProperty -expression $replacement.DefaultValue -properties $evaluatedProperties
            }
        }

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
                    $evaluatedProps[$rep.ReplaceKey] = InternalGet-ReplacementValue -template $template -replaceKey $rep.ReplaceKey -evaluatedProperties $evaluatedProps
                }
            }
            
            # replace file names
            $template.UpdateFilenames | ForEach-Object { 
                $current = $_
                [System.IO.FileInfo[]]$files = (Get-ChildItem $tempWorkDir.FullName ('*{0}*' -f $current.ReplaceKey) -Recurse)
                foreach($file in $files){
                    $file = [System.IO.FileInfo]$file
                    $repvalue = InternalGet-ReplacementValue -template $template -replaceKey $current.ReplaceKey -evaluatedProperties $evaluatedProps
                    $newname = $file.Name.Replace($current.ReplaceKey,$repvalue)
                    [System.IO.FileInfo]$newpath = (Join-Path ($file.Directory.FullName) $newname)
                    Move-Item $file.FullName $newpath.FullName
                }
            }

            if($template.BeforeInstall -ne $null){
                InternalGet-EvaluatedProperty -expression $template.BeforeInstall -properties $evaluatedProps
            }

            # replace content in files
            Import-FileReplacer | Out-Null

            foreach($r in $template.Replacements){
                $rvalue = InternalGet-ReplacementValue -template $template -replaceKey $r.ReplaceKey -evaluatedProperties $evaluatedProps

                $evaluatedProps[$r.ReplaceKey]=$rvalue

                $replacements = @{
                    $r.ReplaceKey = $rvalue
                }

                $replaceArgs = @{
                    folder = $tempWorkDir.FullName
                    replacements = $replacements
                    include = '*'
                    exclude = $null
                }

                if($r.Include -ne $null){
                    $replaceArgs.include = ($r.include -join ';')
                }
                if($r.Exclude -ne $null){
                    $replaceArgs.exclude = ($r.Exclude -join ';')
                }

                Replace-TextInFolder @replaceArgs
            }

            # copy the final result to the destination
            if(-not (Test-Path $destPath.FullName)){
                New-Item -Path $destPath.FullName -ItemType Directory
            }
            [string]$tpath = $tempWorkDir.FullName
            
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

# Helpers for externals

<#
.SYNOPSIS
    This will download and import nuget-powershell (https://github.com/ligershark/nuget-powershell),
    which is a PowerShell utility that can be used to easily download nuget packages.

    If nuget-powershell is already loaded then the download/import will be skipped.

.PARAMETER nugetPsMinModVersion
    The minimum version to import
#>
function Import-NuGetPowershell{
    [cmdletbinding()]
    param(
        $nugetPsMinModVersion = $nugetPsMinModuleVersion
    )
    process{
        # see if nuget-powershell is available and load if not
        $nugetpsloaded = $false
        if((get-command Get-NuGetPackage -ErrorAction SilentlyContinue)){
            # check the module to ensure we have the correct version

            $currentversion = (Get-Module -Name nuget-powershell).Version
            if( ($currentversion -ne $null) -and ($currentversion.CompareTo([version]::Parse($nugetPsMinModVersion)) -ge 0 )){
                $nugetpsloaded = $true
            }
        }

        if(!$nugetpsloaded){
            (new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/ligershark/nuget-powershell/master/get-nugetps.ps1") | iex
        }

        # check to see that it was loaded
        if((get-command Get-NuGetPackage -ErrorAction SilentlyContinue)){
            $nugetpsloaded = $true
        }

        if(-not $nugetpsloaded){
            throw ('Unable to load nuget-powershell, unknown error')
        }
    }
}

<#
.SYNOPSIS
    This will download and import the given version of file-replacer (https://github.com/ligershark/template-builder/blob/master/file-replacer.psm1),
    which can be used to replace text in files under a given folder.

    If file-replacer is already loaded then the download/import will be skipped.

.PARAMETER fileReplacerVersion
    The version to import.
#>
function Import-FileReplacer{
    [cmdletbinding()]
    param(
        [string]$fileReplacerVersion = '0.4.0-beta'
    )
    process{
        $fileReplacerLoaded = $false
        # Replace-TextInFolder
        if(get-command Replace-TextInFolder -ErrorAction SilentlyContinue){
            $fileReplacerLoaded = $true
        }

        # download/import file-replacer
        if(-not $fileReplacerLoaded){
            'Importing file-replacer version [{0}]' -f $fileReplacerVersion | Write-Verbose
            Import-NuGetPowershell | Out-Null
            $pkgpath = (Get-NuGetPackage 'file-replacer' -version $fileReplacerVersion -binpath)
            Import-Module (Join-Path $pkgpath 'file-replacer.psm1') -DisableNameChecking -Global | Out-Null
        }
    }
}

# TODO: Update this later
Export-ModuleMember -function * -Alias *













