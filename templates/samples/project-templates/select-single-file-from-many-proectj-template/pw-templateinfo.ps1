[cmdletbinding()]
param()

$templateInfo = New-Object -TypeName psobject -Property @{
    Name = 'demo-singlefileproj'
    Type = 'ProjectTemplate'
    Description = 'ASP.NET 5 web api project'
    DefaultProjectName = 'MyApiProject'
}

replace $templateInfo 'WebApiProject' {$ProjectName} {$DefaultProjectName}
replace $templateInfo 'SolutionDir' {$SolutionDir} {'..\..\'}
replace $templateInfo '..\..\artifacts' {$ArtifactsDir} {$SolutionDir + 'artifacts'}
replace $templateInfo 'a9914dea-7cf2-4216-ba7e-fecb82baa627' {$ProjectId} {[System.Guid]::NewGuid()}

# when the template is run any filename with the given string will be updated
Update-FileName $templateInfo 'WebApiProject' {$ProjectName}
Add-SourceFile -templateInfo $templateInfo -sourceFiles 'WebApiProject.xproj' -destFiles {"$ProjectName"+".xproj"}

# This will register the template with pecan-waffle
Set-TemplateInfo -templateInfo $templateInfo
