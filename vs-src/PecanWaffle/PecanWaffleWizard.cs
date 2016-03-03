namespace PecanWaffle {
    using EnvDTE;
    using EnvDTE100;
    using EnvDTE80;
    using Microsoft.VisualStudio.TemplateWizard;
    using System;
    using System.Collections;
    using System.Collections.Generic;
    using System.IO;
    using System.IO.Compression;
    using System.Linq;
    using System.Management.Automation;
    using System.Reflection;
    using System.Text;
    using System.Threading.Tasks;
    using System.Windows.Forms;
    public class PecanWaffleWizard : BaseWizard {
        public override void RunStarted(object automationObject, Dictionary<string, string> replacementsDictionary, WizardRunKind runKind, object[] customParams) {
            try {
                base.RunStarted(automationObject, replacementsDictionary, runKind, customParams);
            }
            catch(Exception ex) {
                // TODO: Improve this
                MessageBox.Show(ex.ToString());
            }
        }
        public override void RunFinished() {
            try {
                base.RunFinished();

                Solution4 solution = GetSolution();

                if (solution != null) {
                    string projectFolder = RemovePlaceholderProjectCreatedByVs(ProjectName);
                    if(projectFolder == null) {
                        throw new ApplicationException("project folder could not be found");
                    }
                    string newFolder = new DirectoryInfo(projectFolder).Parent.FullName;
                    var properties = new Hashtable();
                    if (!string.IsNullOrWhiteSpace(solution.FileName)) {
                        properties.Add("SolutionFile", new FileInfo(solution.FileName).FullName);
                        properties.Add("SolutionRoot", new FileInfo(solution.FileName).DirectoryName);
                    }

                    Directory.Delete(projectFolder, true);

                    PowerShellInvoker.Instance.RunPwCreateProjectScript(ProjectName, newFolder, TemplateName, PecanWaffleBranchName, TemplateSource, TemplateSourceBranch, properties);
                    AddProjectsUnderPathToSolution(solution, newFolder, "*.*proj");

                }
                else {
                    // TODO: Improve
                    throw new ApplicationException("Solution is null");
                }
            }
            catch(Exception ex) {
                // TODO: Improve this
                MessageBox.Show(ex.ToString());
            }
        }
    }
}
