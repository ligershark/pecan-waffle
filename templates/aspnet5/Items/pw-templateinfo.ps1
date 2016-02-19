[cmdletbinding()]
param()

# class template
$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'Class'
    Type = 'ItemTemplate'
    Description = 'Creates a C# class'
    DefaultFileName = 'MyClass.cs'
    DefaultNamespace = 'MyProject'
}
$templateInfo | replace (
    ('MyClass', {"$ItemName"}),
    ('MyProject', {$p['Namespace']}, {$DefaultNamespace})
)

$templateInfo | add-sourcefile -sourceFiles 'MyClass.cs' -destFiles {"$ItemName.cs"}
Set-TemplateInfo -templateInfo $templateInfo

# interface template
$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'Interface'
    Type = 'ItemTemplate'
    Description = 'Creates a C# interface'
    DefaultFileName = 'MyInterface.cs'
    DefaultNamespace = 'MyProject'
}
$templateInfo | replace (
    ('MyIterface', {"$ItemName"}),
    ('MyProject', {"$Namespace"}, {"$DefaultNamespace"})
)

$templateInfo | add-sourcefile -sourceFiles 'MyInterface.cs' -destFiles {"$ItemName.cs"}
Set-TemplateInfo -templateInfo $templateInfo
