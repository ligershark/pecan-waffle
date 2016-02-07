This is a prototype of a new command line experience for creating project and item templates. The overarching idea is to create a cross-platform self-contained
command line tool which can be used to create projects/files which doesn't depend on installing a bunch of random tools onto the machine. We can later use this
self-contained tool to enable templates across VS/Yeoman/VSCode.

We are also going to use this as an opportunity to simplify the following areas.

 - Make creating templates easier
 - Make it easier to share templates 
 - Improve the experience with dynamic templates
 
The initial thoughts are to create a prototype in PowerShell which shows the end state. After we provide proof of concept we can implement it
using dnx/dotnet so that it's truly cross platform.

### How to try it

```powershell
# install
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/ligershark/pecan-waffle/master/install.ps1") | iex

# add a new template
Add-Project -templateName aspnet5-empty -destPath C:\temp\pecan-waffle\dest\02
```

To create a new template of your own add a file named `pw-templateinfo.ps1` with content like `https://github.com/ligershark/pecan-waffle/blob/master/templates/aspnet5/EmptyProject/pw-templateinfo.ps1`. Then add the folder as a template source with.

```powershell
Add-TemplateSource -path c:\projects\MyProject\
```

### Initial thoughts
 
I'd like to see some commands like the following in the prototype. `pw` is an alias for `pecan-waffle`
 
```powershell
# This will list both local and remote feeds. For remote feeds we will display the url as well as the local folder where the items were cloned.
pw source list

# Adds a new local folder to search for templates, it will be appended to the bottom of the list.
pw source add c:\mytemplates\

# Adds a new local folder to search for templates, it will be appended to the top of the list (searched is from top->bottom)
pw source add c:\mytemplates\ -first

# Adds a new source which points to a git repo (no auth). When added the repo will be cloned to the localmachine. Then that folder will be added
# as a source. The name of the source will be 'pecan-waffle'. If there exists a source with that name and a different url the name will be
# pecan-waffle(<number>)
pw source add https://github.com/ligershark/pecan-waffle.git 

# Adds a new source which points to a git repo. The name of the source will be pwmaster. If there exists pwmaster then you'll have to pass -force to
# force the update.
pw source add https://github.com/ligershark/pecan-waffle.git pwmaster

# updates all git based sources by getting latest on all repos.
pw source update

pw source update pecan-waffle

# Creates a new project from the aspnet5empty project template. The name of the project will
# be defaulted to a value defined in a .json file.
# The contents of the project template will be added to a new folder in the current working directory.
# The name of the folder will be the project name.
pw template add aspnet5empty

# Similar to the previous command but in this case a new folder for the Project will not be created. 
pw template add aspnet5empty -nofolder

# Creates an aspnet5empty project into the directory c:\projects\<ProjetName>.
# The name of the project will be defaulted to a value defined in a .json file.
pw template add aspnet5empty -dest c:\projects

# Creates and aspnet5empty project with the name MyWebProject into a new folder at c:\projects\MyWebProject
pw template add aspnet5empty -dest c:\projects -projectName MyWebProject

# Creates a new project using the template at c:\templates\aspnet5web with a 
# the project name MyWebProject into the directory c:\projects\MyWebProject 
pw template add c:\templates\aspnet5web -dest c:\projects -projectName MyWebProject

# will add the aspnet5-appsettings item template to the current folder. The default name will be defined in a file associated with the template.
pw template add aspnet5-appsettings

# will add the aspnet5-appsettings item template to the current folder with the name myappsettings.json
# The default name will be defined in a file associated with the template.
pw template add aspnet5-appsettings -dest myappsettings.json

# will add the aspnet5-appsettings item template to c:\projects\mynewweb\appsettings.json
# The default name will be defined in a file associated with the template.
pw template add aspnet5-appsettings -dest c:\projects\mynewweb\appsettings.json


 ```

### Random notes

Default replacements for templates

 - ProjectName (project templates only)
 - DestDirectory
 - PackagesFolder (project templates only)
 - SolutionDir
 - guid1 - guid10 - for new guids


Sample replacement json

```json
{
	"Include":["*","*.*"],
    "Exclude":["pw-*","*.jpg","*.png","*.ico"],
    "Replacements":{
        "MyNamespace":{
            "Value":"%Namespace%"
        },
        "EmptyProject":{
            "Exclude":["*.png","*.ico"],
            "Include":["*.*proj","*.*user"],
            "Value":"%ProjectName"
        }
    }
}
```

Include/Exclude under Replacements will be combined with the top level Include/Exclude