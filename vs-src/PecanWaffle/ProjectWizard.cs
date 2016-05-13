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
    using System.Collections;
    using System.ComponentModel;
    public class ProjectWizard : BaseWizard {
        protected internal Hashtable Properties { get; set; }

        public ProjectWizard() : base() {
            Properties = new Hashtable();
        }

        public static string Name
        {
            get { return "ProjectWizard"; }
        }

        public override void RunStarted(object automationObject, Dictionary<string, string> replacementsDictionary, WizardRunKind runKind, object[] customParams) {
            EnsurePecanWaffleExtracted();
            base.RunStarted(automationObject, replacementsDictionary, runKind, customParams);
        }

        public override void RunFinished() {
            try {
                base.RunFinished();

                // check required properties
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

                if (string.IsNullOrWhiteSpace(TemplateSource)) {
                    TemplateSource = ExtensionInstallDir;
                }

                Solution4 solution = GetSolution();
                if (solution != null) {
                    string projectFolder = RemovePlaceholderProjectCreatedByVs(ProjectName);
                    var properties = new Hashtable();

                    string slnRoot = SolutionDirectory;
                    if (!string.IsNullOrEmpty(SolutionDirectory)) {
                        slnRoot = SolutionDirectory;
                    }
                    if (string.IsNullOrEmpty(slnRoot) && !string.IsNullOrWhiteSpace(solution.FileName)) {
                        slnRoot = new FileInfo(solution.FileName).DirectoryName;
                    }
                    if (string.IsNullOrWhiteSpace(slnRoot)) {
                        throw new ApplicationException("solution is null");
                    }

                    DirectoryInfo projFolderInfo = new DirectoryInfo(projectFolder);
                    properties.Add("SolutionRoot", slnRoot);
                    string newFolder = new DirectoryInfo(projectFolder).Parent.FullName;
                    Directory.Delete(projectFolder, true);

                    PowerShellInvoker.Instance.RunPwCreateProjectScript(ProjectName, projFolderInfo.FullName, TemplateName, TemplateSource, TemplateSourceBranch, properties);
                    // TODO: allow override of pattern via custom parameter
                    AddProjectsUnderPathToSolution(solution, projFolderInfo.FullName, "*.*proj");
                }
                else {
                    throw new ApplicationException("Soluiton is null");
                }

            }
            catch (Exception ex) {
                // TODO: Improve this
                MessageBox.Show(ex.ToString());
            }
        }

        private void EnsurePecanWaffleExtracted() {
            if (!Directory.Exists(PecanWaffleLocalModulePath)) {
                var swDir = new DirectoryInfo(ExtensionInstallDir);
                var foundFiles = swDir.GetFiles("*.nupkg");
                if (foundFiles == null || foundFiles.Length <= 3) {
                    throw new FileNotFoundException(string.Format("Didn't find 3 or more nuget packages to extract in [{0}].", swDir.FullName));
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

        protected string PecanWaffleLocalModulePath
        {
            get
            {
                return Path.Combine(ExtensionInstallDir, @"PwModules\");
            }
        }
    }
}
