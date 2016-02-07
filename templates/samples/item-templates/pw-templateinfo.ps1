[cmdletbinding()]
param()

$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'demo-controllerjs'
    Type = 'ItemTemplate'
    Description = 'ControllerJs'
    DefaultFileName = 'MyApiProject'
}

# Add-Replacement $templateInfo 'ItemName' {$ItemName} {'controller.js'}
Add-Replacement $templateInfo '$safeitemname$' {"$ItemName"}
Update-FileName $templateInfo 'controller.js' {"$ItemName.js"}
Add-SourceFile -templateInfo $templateInfo -sourceFiles 'controller.js' -destFiles {"$ItemName.js"}
Exclude-File $templateInfo 'pw-*.*'
# This will register the template with pecan-waffle
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

Add-Replacement $templateInfo '$safeitemname$' {"ItemName"}
Add-SourceFile -templateInfo $templateInfo -sourceFiles (Get-ChildItem -Path $scriptDir.FullName *)
Exclude-File $templateInfo 'pw-*.*'
# This will register the template with pecan-waffle
Set-TemplateInfo -templateInfo $templateInfo
