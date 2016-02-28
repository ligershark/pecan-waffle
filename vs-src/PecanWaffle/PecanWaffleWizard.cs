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
                    CreateProjectWithPecanWaffle(ProjectName, projectFolder, TemplateName, PecanWaffleBranchName,TemplateSource,TemplateSourceBranch);
                    AddProjectsUnderPathToSolution(solution, projectFolder, "*.*proj");
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
