[cmdletbinding()]
param()

$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'demo-controllerjs'
    Type = 'ItemTemplate'
    Description = 'ControllerJs'
    DefaultFileName = 'MyApiProject'
}

# Add-Replacement $templateInfo 'ItemName' {$ItemName} {'controller.js'}
Add-Replacement $templateInfo '$safeitemname$' {"$ItemName.js"}
Update-FileName $templateInfo 'controller.js' {"$ItemName.js"}
Add-SourceFile -templateInfo $templateInfo -sourceFiles 'controller.js' -destFiles {"$ItemName.js"}

# This will register the template with pecan-waffle
Set-TemplateInfo -templateInfo $templateInfo


$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'demo-angularfiles'
    Type = 'ItemTemplate'
    Description = 'ControllerJs'
    DefaultFileName = 'MyApiProject'
}

Add-Replacement $templateInfo '$safeitemname$' {"$ItemName.js"}
Update-FileName $templateInfo 'controller.js' {"$ItemName.js"}
Add-SourceFile -templateInfo $templateInfo -sourceFiles 'controller.js' -destFiles {"$ItemName.js"}

# This will register the template with pecan-waffle
Set-TemplateInfo -templateInfo $templateInfo
