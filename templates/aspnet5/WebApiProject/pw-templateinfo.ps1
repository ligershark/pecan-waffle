[cmdletbinding()]
param()

$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'aspnet5-webapi'
    Type = 'ProjectTemplate'
    Description = 'ASP.NET 5 web api project'
    DefaultProjectName = 'MyApiProject'
    LicenseUrl = 'https://raw.githubusercontent.com/ligershark/pecan-waffle/master/LICENSE'
    ProjectUrl = 'https://github.com/ligershark/pecan-waffle'
    GitUrl = 'https://github.com/ligershark/pecan-waffle.git'
    GitBranch = 'master'
    BeforeInstall = { 'before install' | Write-Host -ForegroundColor Cyan}
    AfterInstall = { 'after install' | Write-Host -ForegroundColor Cyan}
}

$templateInfo | replace (
    ('WebApiProject', {"$ProjectName"}, {"$DefaultProjectName"}),
    ('SolutionDir', {"$SolutionDir"}, {'..\..\'}),
    ('..\..\artifacts', {"$ArtifactsDir"}, {"$SolutionDir" + 'artifacts'}),
    ('a9914dea-7cf2-4216-ba7e-fecb82baa627', {"$ProjectId"}, {[System.Guid]::NewGuid()})
)

# when the template is run any filename with the given string will be updated
$templateInfo | update-filename (
    ,('WebApiProject', {$ProjectName})
)


# excludes files from the template
Exclude-File $templateInfo 'pw-*.*','*.user','*.suo','*.userosscache','project.lock.json','*.vs*scc'
# excludes folders from the template
Exclude-Folder $templateInfo '.vs','artifacts'

# This will register the template with pecan-waffle
Set-TemplateInfo -templateInfo $templateInfo