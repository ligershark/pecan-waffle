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
                    CreateProjectWithPecanWaffle(ProjectName, projectFolder, TemplateName, PecanWaffleBranchName);
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

        private void CreateProjectWithPecanWaffleOld(string projectName, string destPath) {
            bool hadErrors = false;
            string errorString = "";
            // here is where we want to call pecan-waffle
            try {
                using (PowerShell instance = PowerShell.Create()) {
                    instance.AddScript(_psNewProjectScript);

                    instance.AddParameter("templatename", TemplateName);
                    instance.AddParameter("projectName", projectName);
                    instance.AddParameter("destpath", destPath);
                    if (!string.IsNullOrWhiteSpace(PecanWaffleBranchName)) {
                        instance.AddParameter("pwInstallBranch", PecanWaffleBranchName);
                    }

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

        private string _psNewProjectScript = @"
param($templateName,$projectname,$destpath,$pwInstallBranch)

if([string]::IsNullOrWhiteSpace($templateName)){
    throw ('$templateName is null')
}
if([string]::IsNullOrWhiteSpace($projectname)){
    throw ('$projectname is null')
}
if([string]::IsNullOrWhiteSpace($destpath)){
    throw ('$destpath is null')
}

if([string]::IsNullOrWhiteSpace($pwInstallBranch)){
    $pwInstallBranch = 'master'
}

$destpath = ([System.IO.DirectoryInfo]$destpath)

# parameters declared here
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned | out-null

# TODO: Remove this later and detect version to see if upgrade is needed
$pwNeedsInstall = $true
[System.IO.DirectoryInfo]$localInstallFolder = ""$env:USERPROFILE\Documents\WindowsPowerShell\Modules\pecan-waffle""
if(test-path $localInstallFolder.FullName){
    Remove-Item $localInstallFolder.FullName -Recurse
}

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
    Remove-Module pecan-waffle -ErrorAction SilentlyContinue | Out-Null
    # TODO: Update branch to master or via parameter
    $installUrl = ('https://raw.githubusercontent.com/ligershark/pecan-waffle/{0}/install.ps1' -f $pwInstallBranch)
    &{set-variable -name pwbranch -value $pwInstallBranch;$wc=New-Object System.Net.WebClient;$wc.Proxy=[System.Net.WebRequest]::DefaultWebProxy;$wc.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;Invoke-Expression ($wc.DownloadString($installUrl))}
}

New-PWProject -templateName $templatename -destPath $destpath.FullName -projectName $projectname -noNewFolder
";
    }
}
