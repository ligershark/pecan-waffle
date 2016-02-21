namespace PecanWaffle {
    using EnvDTE;
    using EnvDTE100;
    using EnvDTE80;
    using Microsoft.VisualStudio.TemplateWizard;
    using System;
    using System.Collections.Generic;
    using System.IO;
    using System.IO.Compression;
    using System.Linq;
    using System.Management.Automation;
    using System.Reflection;
    using System.Text;
    using System.Threading.Tasks;
    using System.Windows.Forms;
    public class PecanWaffleWizard : IWizard {
        private Solution4 _solution { get; set; }
        private DTE2 _dte2 { get; set; }
        private string _projectName;

        private string _installScript;
        private string _templateName;

        public void BeforeOpeningFile(ProjectItem projectItem) {
        }

        public void ProjectFinishedGenerating(Project project) {
        }

        public void ProjectItemFinishedGenerating(ProjectItem projectItem) {
        }

        public void RunFinished() {
            if (_dte2 != null) _solution = (Solution4)_dte2.Solution;

            string projectName = _projectName;
            if(_solution != null) {
                string projectFolder = RemovePlaceholderProjectCreatedByVs(projectName);
                CreateProjectWithPecanWaffle(_projectName, projectFolder);
                // look in the dest folder for the newly created project
                string[]projFiles = Directory.GetFiles(projectFolder, @"*.*proj");

                foreach (string path in projFiles) {
                    // TODO: Check to see if the project is already added to the solution
                    _solution.AddFromFile(path, false);
                }
            }
            else {
                System.Windows.Forms.MessageBox.Show("Solution is null");
            }
        }

        private string RemovePlaceholderProjectCreatedByVs(string projectName) {
            bool foundProjToRemove = false;
            var projects = GetProjects();
            Project removedProject = null;
            string projectFolder = null;
            foreach(var proj in projects) {
                if (string.Compare(projectName, proj.Name, StringComparison.OrdinalIgnoreCase) == 0) {
                    string removedProjPath = proj.FullName;
                    _solution.Remove(proj);
                    if (File.Exists(removedProjPath)) {
                        File.Delete(removedProjPath);
                    }
                    projectFolder = new FileInfo(removedProjPath).Directory.FullName;
                    foundProjToRemove = true;
                    removedProject = proj;
                    break;
                }
            }

            if(!foundProjToRemove) {
                MessageBox.Show("project to remove was null");
            }

            return projectFolder;
        }

        private void CreateProjectWithPecanWaffle(string projectName, string destPath) {
            bool hadErrors = false;
            string errorString = "";
            // here is where we want to call pecan-waffle
            try {
                using (PowerShell instance = PowerShell.Create()) {

                    string actualScript = _psNewProjectScript
                                            .Replace(@"<ProjectName>", projectName)
                                            .Replace("<DestPath>",destPath)
                                            .Replace("<InstallScript>", _installScript)
                                            .Replace("<TemplateName>", _templateName)
                                            ;
                    instance.AddScript(actualScript);

                    var result = instance.Invoke();

                    var errorsb = new StringBuilder();
                    if (instance.HadErrors && instance.Streams.Error.Count > 0) {
                        var error = instance.Streams.Error.ReadAll();
                        if (error != null) {
                            foreach (var er in error) {
                                hadErrors = true;
                                errorsb.AppendLine(er.Exception.ToString());
                            }
                        }

                        if (hadErrors) {
                            errorString = errorsb.ToString();
                        }
                    }
                }
            }
            catch (Exception ex) {
                System.Windows.Forms.MessageBox.Show(ex.ToString());
            }

            if (hadErrors) {
                System.Windows.Forms.MessageBox.Show(errorString);
            }
        }
        public void RunStarted(object automationObject, Dictionary<string, string> replacementsDictionary, WizardRunKind runKind, object[] customParams) {
            _dte2 = automationObject as DTE2;
            _templateName = replacementsDictionary["TemplateName"];
            _installScript = replacementsDictionary["InstallScript"];

            string projName;
            if(replacementsDictionary.TryGetValue("$projectname$", out projName)) {
                _projectName = projName;
            }
        }

        public bool ShouldAddProjectItem(string filePath) {
            return false;
        }

        // https://github.com/ligershark/template-builder/blob/master/src/TemplateBuilder/SolutionWizard.cs

        /// <summary>
        /// Gets the projects in a solution recursively.
        /// </summary>
        /// <returns></returns>
        private IList<Project> GetProjects() {
            var projects = _solution.Projects;
            var list = new List<Project>();
            var item = projects.GetEnumerator();

            while (item.MoveNext()) {
                var project = item.Current as Project;
                if (project == null) {
                    continue;
                }

                if (project.Kind == ProjectKinds.vsProjectKindSolutionFolder) {
                    list.AddRange(GetSolutionFolderProjects(project));
                }
                else {
                    list.Add(project);
                }
            }
            return list;
        }

        /// <summary>
        /// Gets the solution folder projects.
        /// </summary>
        /// <param name="solutionFolder">The solution folder.</param>
        /// <returns></returns>
        private static IEnumerable<Project> GetSolutionFolderProjects(Project solutionFolder) {
            var list = new List<Project>();
            for (var i = 1; i <= solutionFolder.ProjectItems.Count; i++) {
                var subProject = solutionFolder.ProjectItems.Item(i).SubProject;
                if (subProject == null) {
                    continue;
                }

                // If this is another solution folder, do a recursive call, otherwise add
                if (subProject.Kind == ProjectKinds.vsProjectKindSolutionFolder) {
                    list.AddRange(GetSolutionFolderProjects(subProject));
                }
                else {
                    list.Add(subProject);
                }
            }
            return list;
        }

        private string GetPathToModuleFile() {
            string path = Path.Combine(GetPecanWaffleExtensionInstallDir(), "pecan-waffle.psm1");
            path = new FileInfo(path).FullName;
            if (!File.Exists(path)) {
                MessageBox.Show(string.Format("Module not found at [{0}]", path));
            }

            return path;
        }

        private string GetPecanWaffleExtensionInstallDir() {
            return (new DirectoryInfo(Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location)).FullName);
        }

        private string _psNewProjectScript = @"
# parameters declared here
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned | out-null
$pwNeedsInstall = $true
try{
    Import-Module pecan-waffle -ErrorAction SilentlyContinue | out-null

    if(-not (Get-Command ""New-PWProject"" -Module pecan-waffle  -errorAction SilentlyContinue)){
        $pwNeedsInstall = $true
    }
}
catch{
    # do nothing
}

if($pwNeedsInstall){
    # TODO: Update branch to master or via parameter
    <InstallScript>
}

# Remove-Module pecan-waffle -Force -ErrorAction SilentlyContinue | out-null
$templatename = '<TemplateName>'
$projectname = '<ProjectName>'
$destpath = '<DestPath>'

$destpath = ([System.IO.DirectoryInfo]$destpath)

New-PWProject -templateName $templatename -destPath $destpath.FullName -projectName $projectname -noNewFolder
";
    }
}
