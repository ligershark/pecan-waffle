[cmdletbinding()]
param()

$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'templatename'
    Type = 'ProjectTemplate'
    Description = 'Template description'
    DefaultProjectName = 'MyProject'
    LicenseUrl = ''
    ProjectUrl = ''
}

$templateInfo | replace (
    ('EmptyProject', {"$ProjectName"}, {"$DefaultProjectName"}),
    ('SolutionDir', {"$SolutionDir"}, {'..\..\'}),
    ('..\..\artifacts', {"$ArtifactsDir"}, {"$SolutionDir" + 'artifacts'}),
    ('97b148d4-829e-4de3-840b-9c6600caa117', {"$ProjectId"}, {[System.Guid]::NewGuid()})
)

# when the template is run any filename with the given string will be updated
Update-FileName $templateInfo 'EmptyProject' {"$ProjectName"}
# excludes files from the template
Exclude-File $templateInfo 'pw-*.*','*.user','*.suo','*.userosscache','project.lock.json','*.vs*scc'
# excludes folders from the template
Exclude-Folder $templateInfo '.vs','artifacts'

# This will register the template with pecan-waffle
Set-TemplateInfo -templateInfo $templateInfo
