[cmdletbinding()]
param()

$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'templatename'
    Type = 'ItemTemplate'
    Description = 'Item description'
}


$templateInfo | replace (
    ,('templatename', {"$ItemName"})
)

$templateInfo | exclude-file 'pw-*.*'

# Adds a single file to the template
$templateInfo | add-sourcefile -sourceFiles 'controller.js' -destFiles {"$ItemName.js"}
Set-TemplateInfo -templateInfo $templateInfo
