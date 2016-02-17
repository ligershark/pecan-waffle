This is a prototype of a new command line experience for creating project and item templates. The overarching idea is to create a cross-platform self-contained
command line tool which can be used to create projects/files which doesn't depend on installing a bunch of random tools onto the machine. We can later use this
self-contained tool to enable templates across VS/Yeoman/VSCode.

[![Build status](https://ci.appveyor.com/api/projects/status/yrif6mr7ep1yt6ct?svg=true)](https://ci.appveyor.com/project/sayedihashimi/pecan-waffle)

We are also going to use this as an opportunity to simplify the following areas.

 - Make creating templates easier
 - Make it easier to share templates 
 - Improve the experience with dynamic templates
 
**The initial thoughts are to create a prototype in PowerShell which shows the end state. After we provide proof of concept we can implement it
using dnx/dotnet so that it's truly cross platform.**

### How to try it

```powershell
# install
&{set-variable -name pwbranch -value 'dev';$wc.Proxy=[System.Net.WebRequest]::DefaultWebProxy;$wc.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;Invoke-Expression ($wc.DownloadString('https://raw.githubusercontent.com/ligershark/pecan-waffle/master/install.ps1'))}

# add a new template
Add-Project -templateName aspnet5-empty -destPath C:\temp\myprojects
```

To create a new template of your own add a file named `pw-templateinfo.ps1` with content like https://github.com/ligershark/pecan-waffle/blob/master/templates/aspnet5/EmptyProject/pw-templateinfo.ps1. Then add the folder as a template source with.

```powershell
Add-TemplateSource -path c:\projects\MyProject\
```

### Video

Watch the 8 minute video on `pecan-waffle` https://youtu.be/Xi5Kn4Lq6Xg.