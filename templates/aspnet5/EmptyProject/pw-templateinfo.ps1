[cmdletbinding()]
param(
    [hashtable]$options = @{}
)

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

$projectName = (Get-ValueOrDefault $options['ProjectName'] 'MyWebProject')
$guid1 = [System.Guid]::NewGuid()
[System.IO.DirectoryInfo]$destDir = (Get-ValueOrDefault $options['DestDir'] '.\')
$solutionDir = (Get-ValueOrDefault $options['SolutionDir'] '..\..\')
$artifactsDir = (Get-ValueOrDefault $options['ArtifactsDir'] ($solutionDir + 'artifacts\'))


# capturing the output directly may not be the best idea here because it's too easy to output something accidently
# instead the user will call a method to set the result

$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'aspnet5-empty'
    Description = 'ASP.NET 5 empty project'
    ProjectName = 'MyEmptyProject'
    SolutionDir = $solutionDir
    ArtifactsDir = $artifactsDir
}

$templateInfo.ArtifactsDir = $templateInfo.SolutionDir

# TODO hook up replacements here as well. It can call a method to register the replacement. The key will be the containing folder

Add-Replacement $templateInfo 'EmptyProject' $templateInfo.ProjectName
Add-Replacement '97b148d4-829e-4de3-840b-9c6600caa117' $guid1
Add-Replacement '97b148d4-829e-4de3-840b-9c6600caa117' $guid1 -rootDir = 'sub\wwwroot' -Include '*','**' -Exclude '*.6','*.1'

# TODO: Implement this function
# This will basically store the templateinfo object so that the caller can reterieve it
# or it could set the template info into a global object somewhere that's indexed by the fullpath
# of folder?
Set-TemplateInfo -templateInfo $templateInfo


