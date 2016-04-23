[cmdletbinding()]
param()

$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'templatename'
    Type = 'ProjectTemplate'
    Description = 'Template description'
    DefaultProjectName = 'MyProject'
    AfterInstall = {
    <# un comment for vs projects
        Update-VisualStuidoProjects -slnRoot ($SolutionRoot)
    #>
    }
}

$templateInfo | replace (
    ('MyProjectName', {"$ProjectName"}, {"$DefaultProjectName"}),
    ('97b148d4-829e-4de3-840b-9c6600caa117', {"$ProjectId"}, {[System.Guid]::NewGuid()})
)

# when the template is run any filename with the given string will be updated
$templateInfo | update-filename (
    ,('MyProjectName', {"$ProjectName"})
)
# excludes files from the template
$templateInfo | exclude-file 'pw-*.*','*.user','*.suo','*.userosscache','project.lock.json','*.vs*scc'
# excludes folders from the template
$templateInfo | exclude-folder '.vs','artifacts','packages','bin','obj'

# This will register the template with pecan-waffle
Set-TemplateInfo -templateInfo $templateInfo
