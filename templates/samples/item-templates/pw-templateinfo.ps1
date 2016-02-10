[cmdletbinding()]
param()

$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'demo-controllerjs'
    Type = 'ItemTemplate'
    Description = 'ControllerJs'
    DefaultFileName = 'MyApiProject'
}


$templateInfo | replace (
    ,('$safeitemname$', {"$ItemName"})
)

$templateInfo | update-filename (
    ,('controller.js', {"$ItemName.js"})
)
$templateInfo | exclude-file 'pw-*.*'

# Adds a single file to the template
$templateInfo | add-sourcefile -sourceFiles 'controller.js' -destFiles {"$ItemName.js"}
Set-TemplateInfo -templateInfo $templateInfo


function InternalGet-ScriptDirectory{
    split-path (((Get-Variable MyInvocation -Scope 1).Value).MyCommand.Path)
}
[System.IO.DirectoryInfo]$scriptDir = (InternalGet-ScriptDirectory)
$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'demo-angularfiles'
    Type = 'ItemTemplate'
    Description = 'ControllerJs'
    DefaultFileName = 'MyApiProject'
}

$templateInfo | replace (
    ,('$safeitemname$', {"$ItemName"})
)

$templateInfo | exclude-file 'pw-*.*'

# Adds all the filesmin the folder to the template
$templateInfo | add-sourcefile -sourceFiles (Get-ChildItem -Path $scriptDir.FullName *)
Set-TemplateInfo -templateInfo $templateInfo
