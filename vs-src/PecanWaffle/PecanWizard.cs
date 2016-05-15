namespace PecanWaffle {
    using EnvDTE;
    using EnvDTE100;
    using EnvDTE80;
    using Microsoft.VisualStudio;
    using Microsoft.VisualStudio.ExtensionManager;
    using Microsoft.VisualStudio.Shell;
    using Microsoft.VisualStudio.Shell.Interop;
    using Microsoft.VisualStudio.TemplateWizard;
    using System;
    using System.Collections;
    using System.Collections.Generic;
    using System.Collections.ObjectModel;
    using System.ComponentModel;
    using System.IO;
    using System.IO.Compression;
    using System.Linq;
    using System.Management.Automation;
    using System.Reflection;
    using System.Text;
    using System.Threading.Tasks;
    using System.Windows.Forms;
    using Microsoft.VisualStudio.ComponentModelHost;
    using Microsoft.VisualStudio.OLE.Interop;

    public class PecanWizard : IWizard {
        protected internal Hashtable Properties { get; set; }
        public Dictionary<string, string> Replacements { get; set; }
        public PecanWizard() {
            Properties = new Hashtable();
        }
        public DTE2 Dte
        {
            get; set;
        }
        public Solution4 Solution
        {
            get;set;
        }
        public string ProjectName
        {
            get; set;
        }
        public string TemplateName
        {
            get;set;
        }

        private string ExtensionInstallDir;
        public string TemplateSource
        {
            get; set;
        }

        public string TemplateSourceBranch
        {
            get; set;
        }

        public string SolutionDirectory
        {
            get; set;
        }

        public string ExtensionId
        {
            get; set;
        }
        #region IWizard impl
        public void BeforeOpeningFile(ProjectItem projectItem) {
        }

        public void ProjectFinishedGenerating(Project project) {
        }

        public void ProjectItemFinishedGenerating(ProjectItem projectItem) {
        }

        public void RunFinished() {
            if (string.IsNullOrWhiteSpace(TemplateSource)) {
                TemplateSource = ExtensionInstallDir;
            }

            var errorSb = new StringBuilder();
            if (string.IsNullOrWhiteSpace(ProjectName)) {
                errorSb.AppendLine("ProjectName is null");
            }
            if (string.IsNullOrWhiteSpace(TemplateName)) {
                errorSb.AppendLine("TemplateName is null");
            }
            if (string.IsNullOrWhiteSpace(TemplateSource)) {
                errorSb.AppendLine("TemplateSource is null");
            }

            if (!string.IsNullOrWhiteSpace(errorSb.ToString())) {
                throw new ApplicationException(errorSb.ToString());
            }

            Solution = (Solution4)Dte.Solution;
            if (Solution != null) {
                string projectFolder = RemovePlaceholderProjectCreatedByVs(ProjectName);
                var properties = new Hashtable();

                string slnRoot = SolutionDirectory;
                if (!string.IsNullOrEmpty(SolutionDirectory)) {
                    slnRoot = SolutionDirectory;
                }
                if (string.IsNullOrEmpty(slnRoot) && !string.IsNullOrWhiteSpace(Solution.FileName)) {
                    slnRoot = new FileInfo(Solution.FileName).DirectoryName;
                }
                if (string.IsNullOrWhiteSpace(slnRoot)) {
                    throw new ApplicationException("solution is null");
                }

                DirectoryInfo projFolderInfo = new DirectoryInfo(projectFolder);
                properties.Add("SolutionRoot", slnRoot);

                if (Replacements != null && Replacements.Keys.Count > 0) {
                    foreach(string key in Replacements.Keys) {
                        string value;
                        if(Replacements.TryGetValue(key,out value) && !string.IsNullOrEmpty(value)) {
                            properties.Add(key, value);
                        }
                    }
                }

                string newFolder = new DirectoryInfo(projectFolder).Parent.FullName;
                Directory.Delete(projectFolder, true);

                PowerShellInvoker.Instance.RunPwCreateProjectScript(ProjectName, projFolderInfo.FullName, TemplateName, TemplateSource, TemplateSourceBranch, properties);
                // TODO: allow override of pattern via custom parameter
                AddProjectsUnderPathToSolution(Solution, projFolderInfo.FullName, "*.*proj");
            }
            else {
                throw new ApplicationException("Soluiton is null");
            }
        }

        public void RunStarted(object automationObject, Dictionary<string, string> replacementsDictionary, WizardRunKind runKind, object[] customParams) {
            Replacements = replacementsDictionary;

            string projName;
            if (replacementsDictionary.TryGetValue("$safeprojectname$", out projName)) {
                ProjectName = projName;
            }

            string tname;
            if (replacementsDictionary.TryGetValue("TemplateName", out tname)) {
                TemplateName = tname;
            }

            string tsource;
            if (replacementsDictionary.TryGetValue("TemplateSource", out tsource)) {
                TemplateSource = tsource;
            }

            string tbranch;
            if (replacementsDictionary.TryGetValue("TemplateSourceBranch", out tbranch)) {
                TemplateSourceBranch = tbranch;
            }

            string slndir;
            if (replacementsDictionary.TryGetValue("$destinationdirectory$", out slndir)) {
                SolutionDirectory = slndir;
            }

            string extensionId;
            if (replacementsDictionary.TryGetValue("ExtensionId", out extensionId)) {
                ExtensionId = extensionId;
            }

            Dte = automationObject as DTE2;

            var _oleServiceProvider = automationObject as Microsoft.VisualStudio.OLE.Interop.IServiceProvider;
            var _serviceProvider = new Microsoft.VisualStudio.Shell.ServiceProvider(_oleServiceProvider);
            var extManager = (IVsExtensionManager)_serviceProvider.GetService(typeof(SVsExtensionManager));

            ExtensionInstallDir = GetExtensionInstallDir(ExtensionId, extManager);
            string pwModsFolder = Path.Combine(ExtensionInstallDir, "PwModules");

            EnsurePecanWaffleExtracted(pwModsFolder, ExtensionInstallDir);

            PowerShellInvoker.Instance.EnsureInstallPwScriptInvoked(ExtensionInstallDir);
        }

        public bool ShouldAddProjectItem(string filePath) {
            return true;
        }
        #endregion

        public string GetExtensionInstallDir(string extensionId,IVsExtensionManager extManager) {
            if (string.IsNullOrWhiteSpace(extensionId)) {
                throw new ApplicationException("ExtensionId is empty");
            }

            if (extManager == null) { throw new ArgumentNullException(nameof(extManager)); }

            var extension = extManager.GetInstalledExtension(extensionId);
            if(extension != null) {
                return extension.InstallPath;
            }

            throw new ApplicationException($"Extension with ID {extensionId} not found");
        }

        private void EnsurePecanWaffleExtracted(string PecanWaffleLocalModulePath, string ExtensionInstallDir) {

            if (!Directory.Exists(PecanWaffleLocalModulePath)) {
                var swDir = new DirectoryInfo(ExtensionInstallDir);
                var foundFiles = swDir.GetFiles("*.nupkg");
                if (foundFiles == null || foundFiles.Length <= 0) {
                    throw new FileNotFoundException(string.Format("Didn't find any files matching TemplateBuilder*.nupkg in [{0}]", swDir.FullName));
                }

                foreach (var file in foundFiles) {
                    var pkgdir = Path.Combine(PecanWaffleLocalModulePath, file.Name);
                    if (!Directory.Exists(pkgdir)) {
                        Directory.CreateDirectory(pkgdir);
                    }
                    ZipFile.ExtractToDirectory(file.FullName, pkgdir);
                }
            }
        }

        public string RemovePlaceholderProjectCreatedByVs(string projectName) {
            bool foundProjToRemove = false;
            var projects = GetProjects();
            Project removedProject = null;
            string projectFolder = null;
            foreach (var proj in projects) {
                if (string.Compare(projectName, proj.Name, StringComparison.OrdinalIgnoreCase) == 0) {
                    string removedProjPath = proj.FullName;
                    Solution.Remove(proj);
                    if (File.Exists(removedProjPath)) {
                        File.Delete(removedProjPath);
                    }
                    projectFolder = new FileInfo(removedProjPath).Directory.FullName;
                    foundProjToRemove = true;
                    removedProject = proj;
                    break;
                }
            }

            if (!foundProjToRemove) {
                // TODO: Improve
                MessageBox.Show("project to remove was null");
            }

            return projectFolder;
        }

        public IList<Project> GetProjects() {
            var projects = Solution.Projects;
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
        public static IEnumerable<Project> GetSolutionFolderProjects(Project solutionFolder) {
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

        public void AddProjectsUnderPathToSolution(Solution4 solution, string folderPath, string pattern = @"*.*proj") {
            string[] projFiles = Directory.GetFiles(folderPath, pattern, SearchOption.AllDirectories);

            bool hadErrors = false;
            StringBuilder errorsb = new StringBuilder();
            foreach (string path in projFiles) {
                // TODO: Check to see if the project is already added to the solution
                try {
                    Project projectAdded = solution.AddFromFile(path, false);
                    // ProjectHelper.UpdatePackagesPathInProject(projectAdded,GetSolution());
                }
                catch (Exception ex) {
                    errorsb.AppendLine(ex.ToString());
                }
            }

            if (hadErrors) {
                MessageBox.Show(errorsb.ToString());
            }
        }

    }
}
