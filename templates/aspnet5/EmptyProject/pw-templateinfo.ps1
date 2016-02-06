[cmdletbinding()]
param()

$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'aspnet5-empty'
    Description = 'ASP.NET 5 empty project'
    DefaultProjectName = 'MyEmptyProject'
    LicenseUrl = 'https://raw.githubusercontent.com/ligershark/pecan-waffle/master/LICENSE'
    ProjectUrl = 'https://github.com/ligershark/pecan-waffle'
    GitUrl = 'https://github.com/ligershark/pecan-waffle.git'
    GitBranch = 'master'
}

$templateInfo.ArtifactsDir = $templateInfo.SolutionDir

Add-Replacement $templateInfo 'EmptyProject' {$ProjectName} {$DefaultProjectName}
Add-Replacement $templateInfo 'SolutionDir' {$solutionDir} {'..\..\'}
Add-Replacement $templateInfo 'ArtifactsDir' {$solutionDir+'artifacts\'} {'..\..\artifacts'}
Add-Replacement '97b148d4-829e-4de3-840b-9c6600caa117' {$ProjectId} {[System.Guid]::NewGuid()}
Add-Replacement '97b148d4-829e-4de3-840b-9c6600caa117' {$ProjectId} {[System.Guid]::NewGuid()} -rootDir = 'sub\wwwroot' -Include '*','**' -Exclude '*.6','*.1'

# when the template is run any filename with the given string will be updated
Update-FileNames $templateInfo 'EmptyProject' {$EmptyProject}
# excludes files from the template
Exclude-Files $templateInfo '*.user','*.suo','*.userosscache','project.lock.json','*.vs*scc'
# excludes folders from the template
Exclude-Folders $templateInfo '.vs','artifacts'


# This will register the template with pecan-waffle
Set-TemplateInfo -templateInfo $templateInfo


