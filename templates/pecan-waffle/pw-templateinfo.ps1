[cmdletbinding()]
param()

$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'pw-project-template'
    Type = 'ItemTemplate'
    Description = 'pecan-waffle project template file'
    DefaultFileName = 'pw-templateinfo'
}
# Adds a single file to the template
$templateInfo | add-sourcefile -sourceFiles 'projecttemplate.ps1'

$templateInfo | replace (
    ,('$safeitemname$', {"$ItemName"})
)

$templateInfo | update-filename (
    ,('projecttemplate.ps1', {'pw-templateinfo.ps1'})
)

$templateInfo | exclude-file 'pw-*.*'

Set-TemplateInfo -templateInfo $templateInfo