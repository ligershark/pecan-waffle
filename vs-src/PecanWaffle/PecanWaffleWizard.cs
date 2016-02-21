namespace PecanWaffle {
    using EnvDTE;
    using EnvDTE80;
    using Microsoft.VisualStudio.TemplateWizard;
    using System;
    using System.Collections.Generic;
    using System.IO;
    using System.IO.Compression;
    using System.Linq;
    using System.Management.Automation;
    using System.Text;
    using System.Threading.Tasks;

    public class PecanWaffleWizard : IWizard {
        public void BeforeOpeningFile(ProjectItem projectItem) {
        }

        public void ProjectFinishedGenerating(Project project) {
        }

        public void ProjectItemFinishedGenerating(ProjectItem projectItem) {
        }

        public void RunFinished() {
        }

        public void RunStarted(object automationObject, Dictionary<string, string> replacementsDictionary, WizardRunKind runKind, object[] customParams) {
            bool hadErrors = false;
            string errorString = "";
            // here is where we want to call pecan-waffle
            try {
                using (PowerShell instance = PowerShell.Create()) {
                    instance.AddScript(_psNewProjectScript);

                    var result = instance.Invoke();

                    var errorsb = new StringBuilder();
                    if ( instance.HadErrors && instance.Streams.Error.Count > 0) {
                        var error = instance.Streams.Error.ReadAll();
                        if(error != null) {
                            foreach(var er in error) {
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
            catch(Exception ex) {
                System.Windows.Forms.MessageBox.Show(ex.ToString());
            }

            if (hadErrors) {
                System.Windows.Forms.MessageBox.Show(errorString);
            }
        }

        public bool ShouldAddProjectItem(string filePath) {
            return true;
        }

        private string _psNewProjectScript = @"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned | out-null
Remove-Module pecan-waffle -Force -ErrorAction SilentlyContinue | out-null
Import-Module C:\data\mycode\pecan-waffle\pecan-waffle.psm1 -Global -DisableNameChecking
$templatename = 'aspnet5-empty'
$projectname = 'mynewproject'
$destpath = 'c:\temp\pw\fromvs\'

$destpath = ([System.IO.DirectoryInfo]$destpath)

New-PWProject -templateName $templatename -destPath $destpath.FullName -projectName $projectname
";
    }
}
