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

    public class ProjectWizard : BaseWizard {
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
                if (string.IsNullOrWhiteSpace(PecanWaffleBranchName)) {
                    errorSb.AppendLine("PecanWaffleBranchName is null");
                }

                if (!string.IsNullOrWhiteSpace(errorSb.ToString())){
                    throw new ApplicationException(errorSb.ToString());
                }



                Solution4 solution = GetSolution();
                if(solution != null) {
                    string projectFolder = RemovePlaceholderProjectCreatedByVs(ProjectName);
                    var properties = new Hashtable();
                    if (!string.IsNullOrWhiteSpace(solution.FileName)) {
                        properties.Add("SolutionFile", new FileInfo(solution.FileName).FullName);
                        properties.Add("SolutionRoot", new FileInfo(solution.FileName).DirectoryName);
                    }
                    string newFolder = new DirectoryInfo(projectFolder).Parent.FullName;
                    Directory.Delete(projectFolder, true);

                    PowerShellInvoker.Instance.RunPwCreateProjectScript(ProjectName, newFolder, TemplateName, PecanWaffleBranchName, ExtensionInstallDir, TemplateSourceBranch, properties);
                    AddProjectsUnderPathToSolution(solution, newFolder, "*.*proj");
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
    }
}
