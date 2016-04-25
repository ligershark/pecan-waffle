[cmdletbinding()]
param()

# all types here must be strings
$global:pecanwafflesettings = New-Object -TypeName psobject -Property @{
    TempDir = ([System.IO.DirectoryInfo]('{0}\pecan-waffle\temp\projtemplates' -f $env:LOCALAPPDATA)).FullName
    TempRemoteDir = ([System.IO.DirectoryInfo]('{0}\pecan-waffle\remote\templates' -f $env:LOCALAPPDATA)).FullName
    Templates = @()
    TemplateSources = @()
    GitSources = @()
    EnableAddLocalSourceOnLoad = $true
    RobocopySystemPath = ('{0}\robocopy.exe' -f [System.Environment]::SystemDirectory)
    RobocopyDownloadUrl = 'https://dl.dropboxusercontent.com/u/40134810/SideWaffle/tools/robocopy.exe'
    LastTempDir = ''
}

function InternalOverrideSettingsFromEnv{
    [cmdletbinding()]
    param(
        [Parameter(Position=0)]
        [object[]]$settings = ($global:PSBuildSettings),

        [Parameter(Position=1)]
        [string]$prefix
    )
    process{
        foreach($settingsObj in $settings){
            if($settingsObj -eq $null){
                continue
            }

            $settingNames = $null
            if($settingsObj -is [hashtable]){
                $settingNames = $settingsObj.Keys
            }
            else{
                $settingNames = ($settingsObj | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)

            }

            foreach($name in ($settingNames.Clone())){
                $fullname = ('{0}{1}' -f $prefix,$name)
                if(Test-Path "env:$fullname"){
                    'Updating setting [{0}] to [{1}]' -f ($settingsObj.$name),((get-childitem "env:$fullname").Value) | Write-Verbose
                    $value = ((get-childitem "env:$fullname").Value)
                    if(-not [string]::IsNullOrWhiteSpace($value)){
                        $settingsObj.$name = ((get-childitem "env:$fullname").Value)
                    }
                }
            }
        }
    }
}
InternalOverrideSettingsFromEnv -settings $global:pecanwafflesettings -prefix 'PW'
# todo: enable overriding settings via env var

function InternalGet-ScriptDirectory{
    split-path (((Get-Variable MyInvocation -Scope 1).Value).MyCommand.Path)
}
$scriptDir = (InternalGet-ScriptDirectory)

function LoadAlphaFS(){
    [cmdletbinding()]
    param(
        [string]$alphafsdllpath = (Join-Path $scriptDir 'AlphaFS.dll')
    )
    process{
        $alphafsdllpath = (Join-Path $scriptDir 'AlphaFS.dll')

        if(-not(Test-Path $alphafsdllpath)){
            throw ('alphafs.dll not found at [{0}]' -f $alphafsdllpath)
        }

        Import-Module -Name $alphafsdllpath
        [Reflection.Assembly]::LoadFile($alphafsdllpath)
    }
}
LoadAlphaFS

function Get-PecanWaffleVersion{
    param()
    process{
        New-Object -TypeName 'system.version' -ArgumentList '0.0.12.0'
    }
}

function Invoke-CommandString{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
        [string[]]$command,
        
        [Parameter(Position=1)]
        $commandArgs,

        $ignoreErrors,

        [switch]$disableCommandQuoting
    )
    process{
        foreach($cmdToExec in $command){
            'Executing command [{0}]' -f $cmdToExec | Write-Verbose
            
            # write it to a .cmd file
            $destPath = "$([Alphaleonis.Win32.Filesystem.Path]::GetTempFileName()).cmd"
            if(InternalTest-File $destPath){InternalRemove-File -filePath $destPath |Out-Null}
            
            try{
                $commandstr = $cmdToExec
                if(-not $disableCommandQuoting -and $commandstr.Contains(' ') -and (-not ($commandstr -match '''.*''|".*"' ))){
                    $commandstr = ('"{0}"' -f $commandstr)
                }

                '{0} {1}' -f $commandstr, ($commandArgs -join ' ') | Set-Content -Path $destPath | Out-Null

                $actualCmd = ('"{0}"' -f $destPath)

                cmd.exe /D /C $actualCmd
                
                if(-not $ignoreErrors -and ($LASTEXITCODE -ne 0)){
                    $msg = ('The command [{0}] exited with code [{1}]' -f $commandstr, $LASTEXITCODE)
                    throw $msg
                }
            }
            finally{
                if(InternalTest-File $destPath){InternalRemove-File $destPath -ErrorAction SilentlyContinue |Out-Null}
            }
        }
    }
}
function Copy-ItemRobocopy{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$sourcePath,

        [Parameter(Position=1,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$destPath,

        [Parameter(Position=2)]
        [string[]]$fileNames,

        [Parameter(Position=3)]
        [switch]$move,

        [Parameter(Position=4)]
        [switch]$ignoreErrors,

        [Parameter(Position=5)]
        [string[]]$foldersToSkip,

        [Parameter(Position=6)]
        [string[]]$filesToSkip,

        [Parameter(Position=7)]
        [switch]$recurse,

        [Parameter(Position=8)]
        [string]$roboCopyOptions = ('/R:1 /W:2 /XA:SH /XJ /FFT'),

        [Parameter(Position=9)]
        [string]$roboLoggingOptions = ('/NFL /NDL /NJS /NJH /NP /NS /NC')
    )
    process{
        [System.Text.StringBuilder]$sb = New-Object -TypeName 'System.Text.StringBuilder'
        $sb.AppendFormat('"{0}" ',$sourcePath.Trim('"').Trim("'").TrimEnd("\")) | out-null
        $sb.AppendFormat('"{0}" ',$destPath.Trim('"').Trim("'").TrimEnd("\")) | out-null

        if($fileNames -eq $null){
            $fileNames = ,'*.*'
        }

        if( ($fileNames -ne $null) -and ($fileNames.Count -gt 0)){
            foreach($file in $fileNames){
                $sb.AppendFormat('"{0}" ',$file)
            }
        }

        if($move){
            $sb.Append('/MOVE ')
        }

        if(-not [string]::IsNullOrWhiteSpace($roboLoggingOptions)){
            $sb.AppendFormat('{0} ',$roboLoggingOptions) | out-null
        }

        if($recurse){
            $sb.Append('/E ') | Out-Null
        }

        if(-not [string]::IsNullOrWhiteSpace($roboCopyOptions)){
            $sb.AppendFormat('{0} ',$roboCopyOptions) | out-null
        }

        if( ($foldersToSkip -ne $null) -and ($foldersToSkip.Length -gt 0)){
            $sb.Append('/XD ') | out-null
            foreach($folder in $foldersToSkip){
                $sb.AppendFormat('"{0}" ',$folder) | out-null
            }
        }

        if( ($filesToSkip -ne $null) -and ($filesToSkip.Length -gt 0)){
            $sb.Append('/XF ') | out-null
            foreach($file in $filesToSkip){
                $sb.AppendFormat('"{0}" ',$file) | out-null
            }
        }

        'Copying files with command [{0} {1}]' -f (Get-Robocopy),$sb.ToString() | write-verbose

        $copyArgs = @{
            'command' = (Get-Robocopy)
            'commandArgs'=$sb.ToString()
        }

        # TODO: Not sure how to properly handle errors, always ignore
        $copyArgs['ignoreErrors']=$true

        Invoke-CommandString @copyArgs
    }
}

function Get-Robocopy{
    [cmdletbinding()]
    param(
        [Parameter(Position=0)]
        [string]$roboCopyPath = ($global:pecanwafflesettings.RobocopySystemPath),
        
        [Parameter(Position=1)]
        [string]$roboCopyDownloadUrl = ($global:pecanwafflesettings.RobocopyDownloadUrl)
    )
    process{
        if(Test-Path $roboCopyPath){
            # return the path
            $roboCopyPath
        }
        else{
            # download it to temp if it's not already there
            $roboCopyTemp = (InternalJoin-Path $global:pecanwafflesettings.TempDir 'robocopy.exe')
            if(-not (Test-Path $roboCopyTemp)){
                # download it now
                'Downloading robocopy.exe from [{0}] to [{1}]' -f $roboCopyDownloadUrl,$roboCopyTemp | Write-Verbose
                (New-Object 'System.Net.WebClient').DownloadFile($roboCopyDownloadUrl,$roboCopyTemp) | write-verbose
            }

            if(-not (Test-Path $roboCopyPath)){
                throw ('Unable to find/download robocopy from [{0}] to [{1}]' -f $roboCopyDownloadUrl,$roboCopyTemp)
            }

            # return the path
            $roboCopyPath
        }
    }
}

<#
.SYNOPSIS
    This will download and import nuget-powershell (https://github.com/ligershark/nuget-powershell),
    which is a PowerShell utility that can be used to easily download nuget packages.

    If nuget-powershell is already loaded then the download/import will be skipped.

.PARAMETER nugetPsMinModVersion
    The minimum version to import
#>
function InternalImport-NuGetPowershell{
    [cmdletbinding()]
    param(
        $nugetPsMinModVersion = '0.2.1.1'
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

function Ensure-DirectoryExists{
    param(
        [Parameter(Position=0)]
        [string]$path
    )
    process{
        if( ($path -ne $null) -and -not ([string]::IsNullOrWhiteSpace($path))) {
            $fullpath = (Get-Fullpath $path)
            if(-not ([Alphaleonis.Win32.Filesystem.Directory]::Exists($fullpath))){
                [Alphaleonis.Win32.Filesystem.Directory]::CreateDirectory($fullpath) | Write-Verbose                
            }
        }
    }
}

#http://jongurgul.com/blog/get-stringhash-get-filehash/
Function InternalGet-StringHash{
    [cmdletbinding()]
    param(
        [String] $text,
        $HashName = "MD5"
    )
    process{
        $sb = New-Object System.Text.StringBuilder
        [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($text))|%{
                [Void]$sb.Append($_.ToString("x2"))
            }
        $sb.ToString()
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

function Get-NewTempDir{
    [cmdletbinding()]
    param()
    process{
        Ensure-DirectoryExists -path $global:pecanwafflesettings.TempDir | Out-Null

        [Alphaleonis.Win32.Filesystem.DirectoryInfo]$newpath = (InternalJoin-Path ($global:pecanwafflesettings.TempDir) ([datetime]::UtcNow.Ticks))
        if([string]::Equals($newpath,$global:pecanwafflesettings.LastTempDir,[System.StringComparison]::OrdinalIgnoreCase)){
            Start-Sleep -Milliseconds 1
            $newpath = (InternalJoin-Path ($global:pecanwafflesettings.TempDir) ([datetime]::UtcNow.Ticks))
        }
        $global:pecanwafflesettings.LastTempDir = $newpath
        New-Item -ItemType Directory -Path ($newpath.FullName) | out-null
        # return the fullpath
        $newpath.FullName
    }
}

# Items related to template sources
function Add-PWTemplateSource{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$path,

        [Parameter(Position=1)]
        $branch = 'master',

        [Parameter(Position=2)]
        [string]$localfolder = ($global:pecanwafflesettings.TempRemoteDir),

        [Parameter(Position=3)]
        [string]$repoName
    )
    process{
        $isGit = $false
        $isLocal = $false
        $isZip = $false

        $path = $path.Trim()
        [string]$pathlastfour = $null
        if($path.Length -gt 4){
            $pathlastfour = $path.Substring($path.Length -4)
        }

        if([string]::Compare('.git',$pathlastfour,[System.StringComparison]::OrdinalIgnoreCase) -eq 0){
            $isGit = $true
        }
        elseif([string]::Compare('.zip',$pathlastfour,[System.StringComparison]::OrdinalIgnoreCase) -eq 0){
            $isZip = $true

            throw ('.zip extension not supported for Add-PWTemplateSource yet')
        }
        else{
            $isLocal = $true
        }

        [Alphaleonis.Win32.Filesystem.DirectoryInfo]$localInstallFolder = $null
        if($isLocal){
            if(-not [Alphaleonis.Win32.Filesystem.Path]::IsPathRooted($path)){
                $localInstallFolder = ([Alphaleonis.Win32.Filesystem.DirectoryInfo](InternalJoin-Path $pwd $path)).FullName
            }
            else{
                $localInstallFolder = ([Alphaleonis.Win32.Filesystem.DirectoryInfo]($path)).FullName
            }
        }

        if([string]::IsNullOrWhiteSpace($localfolder)){
            throw ('localFolder is empty')
        }
        $localfolder = (Get-Fullpath $localfolder)
        Ensure-DirectoryExists -path $localfolder

        if($isGit){
            if([string]::IsNullOrWhiteSpace($repoName)){
                $repoName = ( '{0}-{1}' -f (InternalGet-RepoName -url $path),(InternalGet-StringHash -text $path))
            }
            [Alphaleonis.Win32.Filesystem.DirectoryInfo]$localInstallFolder = (InternalJoin-Path $localfolder $repoName)
            if(-not (InternalTest-Directory $localInstallFolder.FullName)){
                InternalAdd-GitFolder -url $path -repoName $repoName -branch $branch -localfolder $localfolder
            }
        }

        if($localInstallFolder -eq $null){
            throw ('localInstallFolder is null')
        }

        $files = (InternalGet-ChildItem -Path $localInstallFolder.FullName -include 'pw-templateinfo*.ps1' -Recurse -itemType File -exclude '.git','node_modules','bower_components' -ErrorAction SilentlyContinue)

        foreach($file in $files){
            if(-not ([string]::IsNullOrWhiteSpace($file))){
                # run the script
                & (Get-FullPath -path $file)
            }
        }

        $templateSource = New-Object -TypeName psobject -Property @{
            LocalFolder = $repoFolder.FullName
            Url = $path
        }

        $global:pecanwafflesettings.TemplateSources += $templateSource
    }
}

Set-Alias Add-TemplateSource Add-PWTemplateSource

function InternalTest-Directory{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,ValueFromPipeline=$true)]
        [string[]]$dirpath
    )
    process{
        foreach($dir in $dirpath){
            if(-not ([string]::IsNullOrEmpty($dir))){
                [Alphaleonis.Win32.Filesystem.Directory]::Exists($dir)
            }
        }
    }
}

function InternalTest-File{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,ValueFromPipeline=$true)]
        [string[]]$filePath
    )
    process{
        foreach($file in $filePath){
            if(-not ([string]::IsNullOrEmpty($file))){
                $fp = [Alphaleonis.Win32.Filesystem.Path]::GetFullPath($file)
                [Alphaleonis.Win32.Filesystem.File]::Exists($fp)
            }
        }
    }
}

function InternalRemove-File{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,ValueFromPipeline=$true)]
        [string[]]$filePath
    )
    process{
        foreach($file in $filePath){
            if(-not ([string]::IsNullOrEmpty($file))){
                $fp = [Alphaleonis.Win32.Filesystem.Path]::GetFullPath($file)
                [Alphaleonis.Win32.Filesystem.File]::Delete($fp)
            }
        }
    }
}

function InternalRemove-Directory{
   [cmdletbinding()]
    param(
        [Parameter(Position=0,ValueFromPipeline=$true)]
        [string[]]$dirpath,

        [Parameter(Position=1)]
        [switch]$recurse
    )
    process{
        foreach($dir in $dirpath){
            if(-not ([string]::IsNullOrEmpty($dir))){
                $fp = [Alphaleonis.Win32.Filesystem.Path]::GetFullPath($dir)
                [Alphaleonis.Win32.Filesystem.Directory]::Delete($fp,$recurse)
            }
        }
    }
}

function InternalJoin-Path{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,ValueFromPipeline=$true,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$path,

        [Parameter(Position=1)]
        [string]$childPath
    )
    process{
        foreach($p in $path){
            if(-not([string]::IsNullOrEmpty($p))){
                [Alphaleonis.Win32.Filesystem.Path]::Combine($p,$childPath)
            }
        }
    }
}

function InternalGet-ChildItem{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true)]
        [string[]]$path,

        [Parameter(Position=1)]
        [string[]]$include,

        [Parameter(Position=2)]
        [string[]]$exclude,

        [Parameter(Position=3)]
        [ValidateSet('Any','Directory','File')]
        [string]$itemType='Any',

        [Parameter(Position=4)]
        [switch]$recurse
    )
    process{
        if($include -eq $null){
            $include = @('*.*')
        }

        [bool]$includeFiles = $false
        [bool]$includeDirs = $false

        switch ($itemType){
            'Any' {
                $includeFiles = $true
                $includeDirs = $true
            }
            'Directory' {
                $includeDirs = $true
            }
            'File' {
                $includeFiles = $true
            }
            default {
                throw ('Unknown value for itemType [{0}]' -f $itemType)
            }
        }

        [System.IO.SearchOption]$so = [System.IO.SearchOption]::TopDirectoryOnly
        if($recurse){
            $so = [System.IO.SearchOption]::AllDirectories
        }
        
        $allIncludes = New-Object System.Collections.Generic.List``1[string]
        $allExcludes = New-Object System.Collections.Generic.List``1[string]

        $allResults = New-Object System.Collections.Generic.List``1[string]
        foreach($p in $path){
            if([string]::IsNullOrWhiteSpace($p)){
                continue
            }

            foreach($inc in $include){
                if(-not([string]::IsNullOrWhiteSpace($inc))){
                    if($includeFiles){
                        $files = [Alphaleonis.Win32.Filesystem.Directory]::GetFiles($p,$inc,$so)
                        $allIncludes.AddRange($files) | Write-Debug
                    }
                    if($includeDirs){
                        $dirs = [Alphaleonis.Win32.Filesystem.Directory]::GetDirectories($p,$inc,$so)
                        $allIncludes.AddRange($dirs) | Write-Debug
                    }
                }
            }

            foreach($exc in $exclude){
                if(-not([string]::IsNullOrWhiteSpace($exc))){
                    if($includeFiles) {
                        $files = [Alphaleonis.Win32.Filesystem.Directory]::GetFiles($p,$exc,$so)
                        $allExcludes.AddRange($files) | Write-Debug
                    }
                    if($includeDirs) {
                        $dirs = [Alphaleonis.Win32.Filesystem.Directory]::GetDirectories($p,$exc,$so)
                        $allExcludes.AddRange($dirs) | Write-Debug
                    }
                }
            }

            $results =[System.Linq.Enumerable]::Except((Get-Unique -InputObject $allIncludes),(Get-Unique -InputObject $allExcludes))
            $newresults = [System.Linq.Enumerable]::Except($results,$allResults)

            $allResults.AddRange($newresults) | Write-Debug
        }

        # loop through results and return the value
        foreach($r in $allResults){
            $r
        }
    }
}


function InternalGet-RepoName{
    [cmdletbinding()]
    param(
        [Parameter(Position=1,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$url
    )
    process{
        $startIndex = $url.LastIndexOf('/')
        [string]$repoName = [datetime]::UtcNow.Ticks
        if($startIndex -gt 0){
            $repoName = $url.Substring($startIndex +1).Replace('.git','')
        }

        $repoName
    }
}

function InternalAdd-GitFolder{
    [cmdletbinding()]
    param(
        [Parameter(Position=1,Mandatory=$true)]
        [string]$url,

        [Parameter(Position=2)]
        [string]$repoName,

        [Parameter(Position=3,ParameterSetName='git')]
        [string]$branch = 'master',

        [Parameter(Position=4)]
        [string]$localfolder = ($global:pecanwafflesettings.TempRemoteDir)
    )
    begin{
        # TODO: Improve to only call if not loaded
        InternalImport-NuGetPowershell
    }
    process{
        if([string]::IsNullOrWhiteSpace($repoName)){
            $repoName = InternalGet-RepoName -url $url
        }

        if([string]::IsNullOrWhiteSpace($localfolder)){
            throw ('localFolder is empty')
        }

        $localfolder = (Get-Fullpath $localfolder)

        $oldPath = Get-Location
        [Alphaleonis.Win32.Filesystem.DirectoryInfo]$repoFolder = (InternalJoin-Path $localfolder $repoName)
        $path =([Alphaleonis.Win32.Filesystem.DirectoryInfo]$repoFolder).FullName
        try{
            Ensure-DirectoryExists -path $localfolder
            Set-Location $localfolder

            if(-not (InternalTest-Directory $repoFolder.FullName)){
                Execute-CommandString "git clone $url --branch $branch --single-branch $repoName" -ignoreExitCode
            }
        }
        finally{
            Set-Location $oldPath
        }

        $templateSource = New-Object -TypeName psobject -Property @{
            LocalFolder = $repoFolder.FullName
            Url = $url
        }
        $global:pecanwafflesettings.GitSources += $templateSource
    }
}

function Get-PWTemplates{
    [cmdletbinding()]
    param()
    process{
        $Global:pecanwafflesettings.Templates | Select-Object -Property Name,Type | Sort-Object -Property Type,Name,Description
    }
}
Set-Alias Show-Templates Get-PWTemplates -Description 'obsolete: This was added for back compat and will be removed soon'

function Update-PWRemoteTemplates{
    [cmdletbinding()]
    param()
    begin{
        InternalImport-NuGetPowershell
    }
    process{
        foreach($ts in $global:pecanwafflesettings.GitSources){
            if( -not ([string]::IsNullOrWhiteSpace($ts.Url)) -and (InternalTest-Directory $ts.LocalFolder)){
                $oldpath = Get-Location
                try{
                    Set-Location $ts.LocalFolder
                    Execute-CommandString "git pull" -ignoreExitCode
                }
                finally{
                    Set-Location $oldpath
                }
            }
        }
    }
}
Set-Alias Update-RemoteTemplates Update-PWRemoteTemplates -Description 'obsolete: This was added for back compat and will be removed soon'
# Item Related to Templates Below

function TemplateAdd-SourceFile{
    [cmdletbinding()]
    param(
        [Parameter(Position=1,Mandatory=$true)]
        [ValidateNotNull()]
        [string[]]$sourceFiles,

        [Parameter(Position=2)]
        [ScriptBlock[]]$destFiles,

        [Parameter(Position=3,Mandatory=$true,ValueFromPipeline=$true)]
        [ValidateNotNull()]
        $templateInfo
    )
    process{
        if( ($destFiles -ne $null) -and ($destFiles.Count -gt 0) ){
            if($sourceFiles.Count -ne $destFiles.Count){
                throw ('Number of source files [{0}] is not equal number of dest files [{1}]',$sourceFiles.Count,$destFiles.Count)
            }
        }

        if(-not (Internal-HasProperty -inputObject $templateInfo -propertyName 'SourceFiles')){
            Internal-AddProperty -inputObject $templateInfo -propertyName 'SourceFiles' -propertyValue @()
        }

        for($i = 0;$i -lt $sourceFiles.Count;$i++){
            [ScriptBlock]$dest = $null
            if( ($destFiles -ne $null) -and ($destFiles.Count -gt 0) ){
                $dest = $destFiles[$i]
            }

            if($dest -eq $null){
                [string]$str =  '"{0}"' -f $sourceFiles[$i]
                $dest = [ScriptBlock]::Create($str)
            }

            $templateInfo.SourceFiles += New-Object -TypeName psobject -Property @{
#                SourceFile = [Alphaleonis.Win32.Filesystem.FileInfo]($sourceFiles[$i])
                SourceFile = [string]($sourceFiles[$i])
                DestFile = [ScriptBlock]$dest
            }
        }

    }
}

set-alias Add-SourceFile TemplateAdd-SourceFile

function TemplateAdd-Replacement{
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
Set-Alias replaceitem TemplateAdd-Replacement

function TemplateAdd-ReplacementObject{
    param(
        [Parameter(Position=1,Mandatory=$true)]
        [object[][]]$replacementObject,

        [Parameter(Position=2,Mandatory=$true,ValueFromPipeline=$true)]
        $templateInfo,

        [Parameter(Position=3)]
        [string]$rootDir,

        [Parameter(Position=4)]
        [string[]]$include = @('*'),

        [Parameter(Position=5)]
        [string[]]$exclude

    )
    process{
        $global:foo = $replacementObject
        foreach($repobj in $replacementObject){
            # add a replacement for each
            if($repobj.length -lt 2){
                throw ('replacement object requires at least two items, ReplaceKey and ReplaceValue. Num elements in replacement [{0}]{1}' -f $repobj.length,(Get-PSCallStack|Out-String))
            }
            $repKey = $repobj[0]
            $repValue = $repobj[1]
            $defaultValue = [ScriptBlock]$null
            if($repobj.length -gt 2){
                $defaultValue = $repobj[2]
            }

            # see if include/exclude is passed in via replacementObject first
            if( ($repobj.Length -ge 3) -and ($repobj[3] -ne $null)){                
                $include = $repobj[3]
            }

            if( ($repobj.Length -ge 4) -and ($repobj[4] -ne $null)){
               $exclude = $repobj[4]
            }

            $addargs = @{
                TemplateInfo = $templateInfo
                ReplaceKey = $repKey
                ReplaceValue = $repValue
                DefaultValue = $defaultValue
                RootDir = $rootDir
                Include = $include
                Exclude = $exclude
            }

            TemplateAdd-Replacement @addargs
        }
    }    
}

set-alias replace TemplateAdd-ReplacementObject

function TemplateUpdate-FileName{
    [cmdletbinding()]
    param(
        [Parameter(Position=1,Mandatory=$true,ValueFromPipeline = $true)]
        $templateInfo,

        [Parameter(Position=2,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$replaceKey,

        [Parameter(Position=3,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ScriptBlock]$replaceValue,

        [Parameter(Position=4)]
        [ScriptBlock]$defaultValue,

        [Parameter(Position=5)]
        [string[]]$include,

        [Parameter(Position=6)]
        [string[]]$exclude

    )
    process{
        if(-not (Internal-HasProperty -inputObject $templateInfo -propertyName 'UpdateFilenames')){
            Internal-AddProperty -inputObject $templateInfo -propertyName 'UpdateFilenames' -propertyValue @()
        }

        $templateInfo.UpdateFilenames += New-Object -TypeName psobject -Property @{
            ReplaceKey = $replaceKey
            ReplaceValue = $replaceValue
            DefaultValue = $defaultValue
            Include = $include
            Exclude = $exclude
        }
    }
}

function TemplateUpdate-FilenameObject{
    param(
        [Parameter(Position=1,Mandatory=$true)]
        [object[][]]$updateObject,

        [Parameter(Position=2,Mandatory=$true,ValueFromPipeline = $true)]
        $templateInfo
    )
    process{
        foreach($upObj in $updateObject){
            if($upObj -ne $null){
                if($upObj.length -lt 2){
                    throw ('Update object requires at least two values but found [{0}] number of values' -f $upObj.length)
                }

                $defaultValue = [ScriptBlock]$null
                if($upObj.length -ge 3){
                    $defaultValue = $upObj[2]
                }

                $updateArgs = @{
                    templateInfo = $templateInfo
                    replaceKey = ($upObj[0])
                    replaceValue = ($upObj[1])
                    defaultValue = $defaultValue
                }

                if( ($upObj.Length -ge 3) -and ($upObj[3] -ne $null)){
                    $updateArgs['include'] = $upObj[3]
                }

                if( ($upObj.Length -ge 4) -and ($upObj[4] -ne $null)){
                    $updateArgs['exclude'] = $upObj[4]
                }

                TemplateUpdate-FileName @updateArgs
            }
        }
    }
}
# TODO: Change to Update-Path
Set-Alias Update-FileName TemplateUpdate-FilenameObject

function TemplateBefore-Install{
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
Set-Alias beforeinstall TemplateBefore-Install

function TemplateAfter-Install{
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
Set-Alias afterinstall TemplateAfter-Install

function TemplateExclude-File{
    [cmdletbinding()]
    param(
        [Parameter(Position=1,Mandatory=$true)]
        [ValidateNotNull()]
        [string[]]$excludeFiles,

        [Parameter(Position=2,Mandatory=$true,ValueFromPipeline=$true)]
        $templateInfo
    )
    process{
        if(-not (Internal-HasProperty -inputObject $templateInfo -propertyName 'ExcludeFiles')){
            Internal-AddProperty -inputObject $templateInfo -propertyName 'ExcludeFiles' -propertyValue @()
        }

        $templateInfo.ExcludeFiles += $excludeFiles
    }
}
Set-Alias Exclude-File TemplateExclude-File

function TemplateExclude-Folder{
    [cmdletbinding()]
    param(
        [Parameter(Position=1,Mandatory=$true)]
        [ValidateNotNull()]
        [string[]]$excludeFolder,

        [Parameter(Position=2,Mandatory=$true,ValueFromPipeline=$true)]
        $templateInfo
    )
    process{
        if(-not (Internal-HasProperty -inputObject $templateInfo -propertyName 'ExcludeFolder')){
            Internal-AddProperty -inputObject $templateInfo -propertyName 'ExcludeFolder' -propertyValue @()
        }

        $templateInfo.ExcludeFolder += $excludeFolder
    }
}
Set-Alias Exclude-Folder TemplateExclude-Folder

function Clear-PWTemplates{
    [cmdletbinding()]
    param()
    process{
        $global:pecanwafflesettings.Templates.Clear()
    }
}
Set-Alias Clear-AllTemplates Clear-PWTemplates -Description 'obsolete: This was added for back compat and will be removed soon'

function TemplateSet-TemplateInfo{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNull()]
        $templateInfo,

        [Parameter(Position=1)]
        [string]$templateRoot,

        # todo: rename this parameter
        [Parameter(Position=3,ParameterSetName='git')]
        [string]$localfolder = ($global:pecanwafflesettings.TempRemoteDir)
    )
    process{
        if(-not (Internal-HasProperty -inputObject $templateInfo -propertyName 'TemplatePath')){
            Internal-AddProperty -inputObject $templateInfo -propertyName 'TemplatePath' -propertyValue @()

            $url = $templateInfo.SourceUri
            if(-not [string]::IsNullOrWhiteSpace($url)){
                # ensure folder is cloned locally
                # TODO: allow override in template
                $repoName = InternalGet-RepoName -url $url
                $branch = 'master'
                if(-not [string]::IsNullOrWhiteSpace($templateInfo.SourceRepoName)){
                    $repoName = $templateInfo.SourceRepoName
                }
                if(-not [string]::IsNullOrWhiteSpace($templateInfo.SourceBranch)){
                    $branch = $templateInfo.SourceBranch
                }

                if([string]::IsNullOrWhiteSpace($localfolder)){
                    throw ('localFolder is empty')
                }

                $localfolder = (Get-Fullpath $localfolder)

                [Alphaleonis.Win32.Filesystem.DirectoryInfo]$repoFolder = (InternalJoin-Path $localfolder $repoName)
                if(-not (InternalTest-Directory $repoFolder.FullName)){
                    # todo: register so that it can be updated later on via Update-RemoteTemplates
                    InternalAdd-GitFolder -url $url -repoName $repoName -branch $branch -localfolder $localfolder
                }

                [Alphaleonis.Win32.Filesystem.DirectoryInfo]$pathToFolder = $repoFolder.FullName
                if(-not [string]::IsNullOrWhiteSpace($templateInfo.ContentPath)){
                    $pathToFolder = (Get-Fullpath -path (InternalJoin-Path $repoFolder.FullName $templateInfo.ContentPath))
                }
                
                $templateRoot = $pathToFolder
            }

            if( ([string]::IsNullOrWhiteSpace($templateRoot) )) {
                # root is the folder from the calling script
                $templateRoot = ((Get-Item ($MyInvocation.PSCommandPath)).Directory.FullName)
            }

            $templateInfo.TemplatePath = $templateRoot
        }

        $global:pecanwafflesettings.Templates += $templateInfo        
    }
}
Set-Alias Set-TemplateInfo TemplateSet-TemplateInfo

function InternalGet-EvaluatedProperty{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ScriptBlock]$expression,

        [Parameter(Position=1)]
        [hashtable]$properties,

        [Parameter(Position=2)]
        [hashtable]$extraProperties
    )
    process{
        [hashtable]$allProps += $properties
        if($allProps -eq $null){
            $allProps = @{}
        }
        if($extraProperties -ne $null){
            foreach($key in $extraProperties.Keys){
                if(-not [string]::IsNullOrEmpty($extraProperties[$key])){
                    $allProps[$key]=$extraProperties[$key]
                }
            }
        }
        $scriptToExec = [ScriptBlock]::Create({$fargs=$args; foreach($f in $fargs.Keys){ New-Variable -Name $f -Value $fargs.$f };}.ToString() + (InternalGet-CreateStringFor -properties $allProps) + ';' + $expression.ToString())
        $value = & ($scriptToExec) $allProps

        # return the value
        $value
    }
}

function InternalGet-CreateStringFor{
    [cmdletbinding()]
    param(
        [Parameter(Position=1,Mandatory=$true)]
        [hashtable]$properties
    )
    process{
        [System.Text.StringBuilder]$sb = New-Object -TypeName 'System.Text.StringBuilder'
        $Sb.AppendLine('$p=@{}') | out-null
        foreach($key in $properties.Keys){
            $escapedkey = $key.ToString().Replace("'","''")
            $escapedvalue = $properties[$key]
            if(-not [string]::IsNullOrWhiteSpace($escapedvalue)){
                $escapedvalue = $escapedvalue.ToString().Replace("'","''")
            }
            $str = ('$p[''{0}''] = ''{1}''' -f $escapedkey, $escapedvalue)
            $sb.AppendLine($str) | Out-Null
        }

        # return the result
        $sb.ToString()
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

        [Parameter(Position=2)]
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

function New-PWProject{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [string]$templateName,

        [Parameter(Position=1)]
        [string]$destPath = ($pwd),

        [Parameter(Position=2)]
        [string]$projectName = 'MyNewProject',

        [Parameter(Position=3)]
        $properties,

        [Parameter(Position=4)]
        [switch]$noNewFolder
    )
    process{
        # find the project template with the given name
        $template = ($Global:pecanwafflesettings.Templates|Where-Object {$_.Type -eq 'ProjectTemplate' -and $_.Name -eq $templateName}|Select-Object -First 1)

        if([string]::IsNullOrEmpty($destPath)){
            $destPath = $pwd
        }

        if(-not [Alphaleonis.Win32.Filesystem.Path]::IsPathRooted($destPath)){
            [string]$destPath = (InternalJoin-Path $pwd $destPath)
        }

        [string]$destPath = Get-Fullpath -path $destPath

        if($template -eq $null){
            throw ('Did not find a project template with the name [{0}]' -f $templateName)
        }

        if( (-not ($PSBoundParameters.ContainsKey(‘noNewFolder’))) -and ($template.CreateNewFolder -ne $null) ){
                $noNewFolder = (-not [bool]($template.CreateNewFolder))
        }

        if(-not $noNewFolder){
            [string]$destPath = (InternalJoin-Path $destPath $projectName)
        }

        if($properties -eq $null){
            $properties = @{}
        }

        if(-not ([string]::IsNullOrWhiteSpace($projectName) ) ){
            $properties['ProjectName'] = $projectName
        }

        InternalNew-PWTemplate -template $template -destPath $destPath -properties $properties
    }
}
Set-Alias Add-Project New-PWProject -Description 'obsolete: This was added for back compat and will be removed soon'

function New-PWItem{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [string]$templateName,

        [Parameter(Position=1)]
        [string]$destPath,

        [Parameter(Position=2)]
        [string]$itemName,

        [Parameter(Position=3)]
        [string]$destFilename,

        [Parameter(Position=4)]
        [hashtable]$properties
    )
    process{
        # find the project template with the given name
        $template = ($Global:pecanwafflesettings.Templates|Where-Object {$_.Type -eq 'ItemTemplate' -and $_.Name -eq $templateName}|Select-Object -First 1)

        if(-not [Alphaleonis.Win32.Filesystem.Path]::IsPathRooted($destPath)){
            $destPath = (InternalJoin-Path $pwd $destPath)
        }

        $destPath = (Get-Fullpath $destPath)

        if($template -eq $null){
            throw ('Did not find an item template with the name [{0}]' -f $templateName)
        }

        if($properties -eq $null){
            $properties = @{}
        }

        if(-not ([string]::IsNullOrWhiteSpace($itemName))) {
            $properties['ItemName'] = $itemName
        }
        if(-not ([string]::IsNullOrWhiteSpace($destFilename))){
            $properties['DestFileName'] = $destFilename
        }

        InternalNew-PWTemplate -template $template -destPath $destPath -properties $properties
    }
}
Set-Alias Add-Item New-PWItem -Description 'obsolete: This was added for back compat and will be removed soon'

function InternalGet-EvaluatedPropertiesFrom{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [object]$template,
        [Parameter(Position=1)]
        [hashtable]$properties,
        [Parameter(Position=2)]
        [string]$templateWorkDir
    )
    process{
        # eval properties here
        $evaluatedProps = @{}
        if($properties -ne $null){
            foreach($key in $properties.Keys){
                $evaluatedProps[$key]=$properties[$key]
            }
        }

        if($templateWorkDir -ne $null){
            $evaluatedProps['templateWorkingDir'] = $templateWorkDir
        }
        # add all the properties of $template into evaluatedProps
        foreach($name in $template.psobject.Properties.Name){
            $evaluatedProps[$name]=($template.$name)
        }

        if($template.Replacements -ne $null){
            foreach($rep in $template.Replacements){
                $evaluatedProps[$rep.ReplaceKey] = InternalGet-ReplacementValue -template $template -replaceKey $rep.ReplaceKey -evaluatedProperties $evaluatedProps
            }
        }

        # return the result
        $evaluatedProps
    }
}

function InternalNew-PWTemplate{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [object]$template,

        [Parameter(Position=1)]
        [string]$destPath,

        [Parameter(Position=2)]
        [hashtable]$properties
    )
    process{
        [Alphaleonis.Win32.Filesystem.DirectoryInfo]$tempWorkDir = Get-NewTempDir
        [string]$sourcePath = $template.TemplatePath
        
        if([string]::IsNullOrWhiteSpace($destPath)){
            throw ('destPath is empty' -f $destPath)
        }

        $destPath = (Get-Fullpath -path $destPath)

        try{
            # eval properties here
            $evaluatedProps =  InternalGet-EvaluatedPropertiesFrom -template $template -properties $properties -templateWorkDir $tempWorkDir.FullName

            $evaluatedProps['FinalDestPath'] = $destPath

            if($template.BeforeInstall -ne $null){
                InternalGet-EvaluatedProperty -expression $template.BeforeInstall -properties $evaluatedProps
            }

            if( ($template.SourceFiles -eq $null) -or ($template.SourceFiles.Count -le 0)){
                # copy all of the files to the temp directory
                'Copying template files from [{0}] to [{1}]' -f $template.TemplatePath,$tempWorkDir.FullName | Write-Verbose
                Copy-ItemRobocopy -sourcePath $sourcePath -destPath $tempWorkDir.FullName -filesToSkip ($template.ExcludeFiles) -foldersToSkip ($template.ExcludeFolder) -recurse -ignoreErrors
            }
            else{
                foreach($sf in  $template.SourceFiles){
                    $source = $sf.SourceFile;
                    
                    $sourceItem = ([Alphaleonis.Win32.Filesystem.FileInfo](Get-Fullpath (InternalJoin-Path $sourcePath $source)))
                    $filename = ($sourceItem|Select-Object -ExpandProperty Name)
                    [hashtable]$extraProps = @{
                        'ThisItemName' = ($filename.TrimEnd($sourceItem.Extension))
                        'ThisItemFileName' = $filename
                    }

                    $dest = (InternalGet-EvaluatedProperty -expression ($sf.DestFile) -properties $evaluatedProps -extraProperties $extraProps)
                    
                    if([string]::IsNullOrWhiteSpace($dest)){
                        throw ('Dest is null or empty for source [{0}]' -f $source)
                    }

                    $destItem = (InternalJoin-Path $tempWorkDir.FullName $dest)
                    $destFolder = (Split-Path -Path $destItem -Parent)
                    $destName = (Split-Path -Path $destItem -Leaf)
                    Copy-ItemRobocopy -sourcePath ($sourceItem.DirectoryName) -destPath $destFolder -fileNames $sourceItem.Name -ignoreErrors
                    if(-not [string]::Equals($sourceItem.Name,$destName,[System.StringComparison]::OrdinalIgnoreCase)){
                        # move the file to the new file name
                        $oldloc = Get-Location
                        try{
                            Set-Location $destFolder
                            Move-Item -Path $sourceItem.Name -Destination $destName
                        }
                        finally{
                            Set-Location -Path $oldloc
                        }
                    }
                }
            }

            <# 
            *****TODO*****: Disabled this for now, revisit this later
            **************: Instead of the below user robocopy to move the file to a temp dir and then delete the temp dir
            #>
            # remove excluded files (in some cases excluded files can still be copied to temp
            #   for example if you specify sourcefile/destfile and include a file that should be excluded
            $excludeStr = '';
            if( ($template.ExcludeFiles -ne $null) -and ( $template.ExcludeFiles.Count -gt 0) ){
                $excludeStr += ($template.ExcludeFiles -join ';')
            }
            if( ($template.ExcludeFolder -ne $null) -and ($template.ExcludeFolder.Count -gt 0) ){
                $excludeStr += ($template.ExcludeFolder -join ';')
            }

            if(-not [string]::IsNullOrWhiteSpace($excludeStr) ){
                (Get-ChildItem $tempWorkDir.FullName $excludeStr -Recurse -File) | Remove-Item 
            }
            <# ****************************************** #>

            # replace file names
            if($template.UpdateFilenames -ne $null){
                foreach($current in $template.UpdateFilenames){
                    # see if there is any matching directory names

                    $repvalue = InternalGet-EvaluatedProperty -expression $current.ReplaceValue -properties $evaluatedProps
                    if([string]::IsNullOrWhiteSpace($repvalue) -and ($current.DefaultValue -ne $null)){
                        $repvalue = InternalGet-EvaluatedProperty -expression $current.DefaultValue -properties $evaluatedProps
                    }

                    # update directory names
                    $gciparams = @{
                        Path = $tempWorkDir.FullName # + '\*'
                        Include=('*{0}*' -f $current.ReplaceKey)
                        Recurse = $true
                        ItemType='Directory'
                        # Directory=$true
                    }

                    if( ($current.Include -ne $null) -and ($current.Include.Length -gt 0) ){
                        # 'Overriding include with [{0}]' -f ($current.Include -join ';') | Write-Host -ForegroundColor Cyan
                        $gciparams.Include = $current.Include
                    }

                    if( ($current.Exclude -ne $null) -and ($current.Exclude.Length -gt 0) ){
                        #'Overriding Exclude with [{0}]' -f ($current.Exclude -join ';') | Write-Host -ForegroundColor Cyan
                        $gciparams.Exclude = $current.Exclude
                        # $gciparams | Out-String | Write-Host -ForegroundColor Cyan
                    }

                    (InternalGet-ChildItem @gciparams) |
                        Select-Object -Property FullName,Name,Parent | ForEach-Object {
                            $folderPath = $_.FullName
                            $folderName = $_.Name
                            $parent = $_.Parent
                            $newname = $folderName.Replace($current.ReplaceKey, $repvalue)
                            $newPath = (InternalJoin-Path $parent.FullName $newname)
                            if(InternalTest-Directory $folderPath){
                                # Move-Item -Path $folderPath -Destination $newPath
                                Copy-ItemRobocopy -sourcePath $folderPath -destPath $newPath -move -recurse -ignoreErrors
                                # Rename-Item -Path $folderPath -NewName $newPath
                            }
                        }
                                          
                    # update filenames
                    $gciparams['ItemType']='File'
                    # $gciparams['File']=$true
                    $global:lastgciparms = $gciparams
                    $files = ([string[]](InternalGet-ChildItem @gciparams))
                    foreach($file in ($files)){
                        #'** {0}' -f $file|Write-Host -ForegroundColor Cyan
                        $file = [Alphaleonis.Win32.Filesystem.FileInfo]$file

                        if([string]::IsNullOrWhiteSpace($repvalue) -and ($current.DefaultValue -ne $null)){
                            $repvalue = InternalGet-EvaluatedProperty -expression $current.DefaultValue -properties $evaluatedProps
                        }

                        $newname = $file.Name.Replace($current.ReplaceKey, $repvalue)
                        [Alphaleonis.Win32.Filesystem.FileInfo]$newpath = (InternalJoin-Path ($file.Directory.FullName) $newname)
                        
                        [Alphaleonis.Win32.Filesystem.File]::Move($file.Fullname,$newpath.FullName)
                    }
                }
            }

            # replace content in files
            InternalImport-FileReplacer | Out-Null

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
            Ensure-DirectoryExists -path $destPath
            Copy-ItemRobocopy -sourcePath $tempWorkDir.FullName -destPath $destPath -ignoreErrors -recurse

            if($template.AfterInstall -ne $null){
                InternalGet-EvaluatedProperty -expression $template.AfterInstall -properties $evaluatedProps
            }
        }
        finally{
            # delete the temp dir and ignore any errors
            if(InternalTest-Directory $tempWorkDir.FullName){
                Remove-Item $tempWorkDir.FullName -Recurse -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }
}

function Copy-TemplateSourceFiles{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNull()]
        [object]$template,
        
        [ValidateNotNullOrEmpty()]
        [Parameter(Position=1,Mandatory=$true)]
        [string]$destFolderPath
    )
    process{
        if( ($template.SourceFiles -eq $null) -or ($template.SourceFiles.Count -le 0)){
            $excludeFiles = @()
            foreach($exclude in $excludeFiles){
                if(-not ([string]::Equals('pw-*.*',$exclude,[System.StringComparison]::OrdinalIgnoreCase)==0)){
                    $excludeFiles += $exclude
                }
            }
   
            [string]$sourcePath = $template.TemplatePath
            'Copying template files from [{0}] to [{1}]' -f $template.TemplatePath, $destFolderPath | Write-Verbose
            Copy-ItemRobocopy -sourcePath $sourcePath -destPath $destFolderPath -filesToSkip ($excludeFiles) -foldersToSkip ($template.ExcludeFolder) -recurse -ignoreErrors
        }
        else{
            throw ('sourceFiles not supported for vsix yet')
        <#
            foreach($sf in  $template.SourceFiles){
                $source = $sf.SourceFile;
               
                                    
                # [System.IO.FileInfo]$sourceFile = (Join-Path $mappedSourcePath $source)
                $sourceItem = Get-Item (Join-Path $mappedSourcePath $source)
                [hashtable]$extraProps = @{
                    'ThisItemName' = ($sourceItem|Select-Object -ExpandProperty BaseName)
                    'ThisItemFileName' = ($sourceItem|Select-Object -ExpandProperty Name)
                }

                $dest = (InternalGet-EvaluatedProperty -expression ($sf.DestFile) -properties $evaluatedProps -extraProperties $extraProps)
                    
                if([string]::IsNullOrWhiteSpace($dest)){
                    throw ('Dest is null or empty for source [{0}]' -f $source)
                }

                $destItem = (Join-Path $tempWorkDir.FullName $dest)
                $destFolder = (Split-Path -Path $destItem -Parent)
                $destName = (Split-Path -Path $destItem -Leaf)
                Copy-ItemRobocopy -sourcePath ($sourceItem.DirectoryName) -destPath $destFolder -fileNames $sourceItem.Name -ignoreErrors
                if(-not [string]::Equals($sourceItem.Name,$destName,[System.StringComparison]::OrdinalIgnoreCase)){
                    # move the file to the new file name
                    $oldloc = Get-Location
                    try{
                        Set-Location $destFolder
                        Move-Item -Path $sourceItem.Name -Destination $destName
                    }
                    finally{
                        Set-Location -Path $oldloc
                    }
                }
            }
            #>
        }
    }
}

# Helpers for externals
<#
.SYNOPSIS
    This will download and import the given version of file-replacer (https://github.com/ligershark/template-builder/blob/master/file-replacer.psm1),
    which can be used to replace text in files under a given folder.

    If file-replacer is already loaded then the download/import will be skipped.

.PARAMETER fileReplacerVersion
    The version to import.
#>
function InternalImport-FileReplacer{
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
            InternalImport-NuGetPowershell | Out-Null
            $pkgpath = (Get-NuGetPackage 'file-replacer' -version $fileReplacerVersion -binpath)
            Import-Module (InternalJoin-Path $pkgpath 'file-replacer.psm1') -DisableNameChecking -Global | Out-Null
        }
    }
}

# functions to enable working with long paths

function Get-FullPath{
    [cmdletbinding()]
    param(
        [string[]]$path
    )
    process{
        # call robo copy to get the full path
        foreach($p in $path){
            if(-not ([string]::IsNullOrWhiteSpace($p))){
                [Alphaleonis.Win32.Filesystem.Path]::GetFullPath($p)
            }
        }
    }
}

function Test-LongPath{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [string[]]$path,

        [Parameter(Position=1)]
        [ValidateSet('Any','Container','Leaf')]
        [string]$pathType
    )
    process{
        
    }
}

if($global:pecanwafflesettings.EnableAddLocalSourceOnLoad -eq $true){
    Add-PWTemplateSource -path (InternalJoin-Path $scriptDir 'templates\pecan-waffle')
    Add-PWTemplateSource -path (InternalJoin-Path $scriptDir 'templates\aspnet5')
    
}

Remove-Module pecan-waffle-visualstudio -Force -ErrorAction SilentlyContinue | out-null
Import-Module (InternalJoin-Path (InternalGet-ScriptDirectory) 'pecan-waffle-visualstudio.psm1') -Global -DisableNameChecking


# TODO: Update this later
if( ($env:IsDeveloperMachine -eq $true) ){
    # you can set the env var to expose all functions to importer. easy for development.
    # this is required for pester testing
    Export-ModuleMember -function * -Alias *
}
else{
    Export-ModuleMember -function Get-*,Set-*,Invoke-*,Save-*,Test-*,Find-*,Add-*,Remove-*,Test-*,Open-*,New-*,Import-*,Clear-*,Update-*,Copy-*,Ensure-* -Alias *
}