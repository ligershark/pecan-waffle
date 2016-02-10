[cmdletbinding()]
param()

$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'pw project template'
    Type = 'ItemTemplate'
    Description = 'pecan-waffle project template file'
    DefaultFileName = 'pw-templateinfo'
}
# Adds a single file to the template
Add-SourceFile -templateInfo $templateInfo -sourceFiles 'projecttemplate.ps1' -destFiles {"$ItemName.ps1"}

replace $templateInfo '$safeitemname$' {"$ItemName"}
Update-FileName $templateInfo 'projecttemplate.ps1' {"$ItemName.ps1"}
Exclude-File $templateInfo 'pw-*.*'

Set-TemplateInfo -templateInfo $templateInfo