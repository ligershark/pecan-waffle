This is a prototype of a new command line experience for creating project and item templates. The overarching idea is to create a cross-platform self-contained
command line tool which can be used to create projects/files which doesn't depend on installing a bunch of random tools onto the machine. We can later use this
self-contained tool to enable temlates across VS/yeoman/VSCode.

We are also going to use this as an opportunity to simplify the following areas.

 - Make creating templates easier
 - Make it easier to share templates 
 - Improve the experience with dynamic templates
 
 The initial thoughts are to create a prototype in PowerShell which shows the end state. After we prove that we want to do this we can implement it
 using dnx/dotnet so that it's truly cross platform.
 
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
# as a source. The name of te source will be 'pecan-waffle'. If there exists a source with that name and a different url the name will be
# pecan-waffle(<number>)
pw source add https://github.com/ligershark/pecan-waffle.git 

# Adds a new source which points to a git repo. The name of the source will be pwmaster. If there exists pwmaster then you'll have to pass -force to
# force the update.
pw source add https://github.com/ligershark/pecan-waffle.git pwmaster

# updates all git based sources by getting latest on all repos.
pw source update

pw source update pecan-waffle

# creates a new project from the aspnet5empty project template. It will be created in a new folder either determined by the name of the
# template itself of from a file which defines the default project name.
pw template add aspnet5empty

# creates an aspnet5empty project into the directory c:\projects\mynewweb
pw template add aspnet5empty -dest c:\projects\mynewweb

# will add the aspnet5-appsettings item template to the current folder. The default name will be defined in a file associated with the template.
pw template add aspnet5-appsettings

# will add the aspnet5-appsettings item template to the current folder with the name myappsettings.json
# The default name will be defined in a file associated with the template.
pw template add aspnet5-appsettings -dest myappsettings.json.

# will add the aspnet5-appsettings item template to c:\projects\mynewweb\appsettings.json
# The default name will be defined in a file associated with the template.
pw template add aspnet5-appsettings -dest c:\projects\mynewweb\appsettings.json.
 ```
 