namespace PecanWaffle {
    using Microsoft.VisualStudio.Shell;
    using Microsoft.VisualStudio.Shell.Interop;
    using System;
    using System.Collections;
    using System.Collections.Generic;
    using System.Collections.ObjectModel;
    using System.Linq;
    using System.Management.Automation;
    using System.Text;
    using System.Threading.Tasks;
    using System.Windows;
    public class PowerShellInvoker {
        private static PowerShellInvoker instance;
        private static object instancelock = new object();

        private PowerShell PsInstance { get; set; }
        private bool HasRunInstallScript { get; set; }
        public PowerShellInvoker() {
            PsInstance = PowerShell.Create();
        }

        ~PowerShellInvoker() {
            if(PsInstance != null) {
                PsInstance.Dispose();
                PsInstance = null;
            }
        }

        public static PowerShellInvoker Instance
        {
            get
            {
                if(instance == null) {
                    lock (instancelock) {
                        instance = new PowerShellInvoker();
                    }
                }
                return instance;
            }
        }

        protected bool WriteOutput
        {
            get
            {
                var pwverbosestr = Environment.GetEnvironmentVariable("PecanWaffleVerbose");
                if (!string.IsNullOrWhiteSpace(pwverbosestr) &&
                    string.Equals("true", pwverbosestr, StringComparison.OrdinalIgnoreCase)){
                    return true;
                }
                return false;
            }
        }
        public string GetStringFrom(Collection<PSObject> invokeResult) {
            if (invokeResult == null) { throw new ArgumentNullException(nameof(invokeResult)); }
            StringBuilder sb = new StringBuilder();
            foreach (var result in invokeResult) {
                sb.AppendLine(result.ToString());
            }
            return sb.ToString();
        }
        public void WriteToOutputWindow(string message) {
            IVsOutputWindow outWindow = Package.GetGlobalService(typeof(SVsOutputWindow)) as IVsOutputWindow;

            Guid customGuid = new Guid("5e2e5362-86e1-466e-956b-391841275c59");
            string customTitle = "pecan-waffle";
            outWindow.CreatePane(ref customGuid, customTitle, 1, 1);

            IVsOutputWindowPane customPane;
            outWindow.GetPane(ref customGuid, out customPane);

            customPane.OutputString(message);
            customPane.Activate();

            var logFilePath = Environment.GetEnvironmentVariable("PecanWaffleLogFilePath");
            if (!string.IsNullOrWhiteSpace(logFilePath)) {
                System.IO.File.AppendAllText(logFilePath, $"{message}{Environment.NewLine}");
            }

        }
        public void EnsureInstallPwScriptInvoked(string extensionInstallDir) {
            PsInstance = PowerShell.Create();
            PsInstance.AddScript(_psInstallPecanWaffleScript);
            PsInstance.AddParameter("extensionInstallDir",extensionInstallDir);
            var result = PsInstance.Invoke();

            if (WriteOutput) {
                WriteToOutputWindow(GetStringFrom(result));
            }

            bool hadErrors;
            string errorString = GetErrorStringFrom(PsInstance, out hadErrors);
            if(WriteOutput) {
                WriteToOutputWindow(errorString);
            }
        }
        public void RunPwCreateProjectScript(string projectName, string destPath, string templateName, string templateSource, string templateSourceBranch, Hashtable properties) {
            bool hadErrors;
            string errorString = "";
            // here is where we want to call pecan-waffle
            try {
                var instance = PsInstance;
                PsInstance.AddScript(_psNewProjectScript);

                PsInstance.AddParameter("templateName", templateName);
                PsInstance.AddParameter("projectName", projectName);
                PsInstance.AddParameter("destPath", destPath);
                
                if (!string.IsNullOrWhiteSpace(templateSource)) {
                    PsInstance.AddParameter("TemplateSource", templateSource);
                }
                if (!string.IsNullOrWhiteSpace(templateSourceBranch)) {
                    PsInstance.AddParameter("TemplateSourceBranch", templateSourceBranch);
                }

                if (properties != null) {
                    PsInstance.AddParameter("Properties", properties);
                }

                try {
                    var result = PsInstance.Invoke();
                }
                catch(Exception ex) {
                    string msg = WriteOutput ? 
                                    $"An error occurred, see output window for more details {ex.ToString()}" : 
                                    $"An error occurred. {ex.ToString()}";
                    MessageBox.Show(msg);
                }
                
                errorString = GetErrorStringFrom(PsInstance, out hadErrors);

                if (hadErrors && WriteOutput) {
                    WriteToOutputWindow(errorString);
                }
            }
            catch (Exception ex) {
                // TODO: Improve
                throw ex;
            }

            if (hadErrors) {
                // TODO: Improve
                throw new ApplicationException(errorString);
            }
        }
        private string GetErrorStringFrom(PowerShell instance) {
            bool notused;
            return GetErrorStringFrom(instance, out notused);
        }
        private string GetErrorStringFrom(PowerShell PsInstance, out bool hadErrors) {
            hadErrors = false;
            var errorsb = new StringBuilder();
            var error = PsInstance.Streams.Error.ReadAll();
            if (error != null) {
                foreach (var er in error) {
                    hadErrors = true;
                    errorsb.AppendLine(er.Exception.ToString());
                }
            }

            return errorsb.ToString();
        }

        private string _psNewProjectScript = @"
param($templateName,$projectname,$destpath,$templateSource,$templateSourceBranch,$properties)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted | out-null
$destpath = ([System.IO.DirectoryInfo]$destpath)

if(-not [string]::IsNullOrWhiteSpace($templateSource)){
    Clear-PWTemplates
    Add-PWTemplateSource -path $templateSource -branch $templateSourceBranch
    # TODO: Update to just update this specific template
    Update-RemoteTemplates
}

New-PWProject -templateName $templatename -destPath $destpath.FullName -noNewFolder -projectName $projectname -properties $properties";

        private string _psInstallPecanWaffleScript = @"
param($extensionInstallDir)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted | out-null

$localPath = $env:PWLocalPath
if( (-not [string]::IsNullOrWhiteSpace($localPath)) -and (Test-Path $localPath)){
    Import-Module ""$localPath\pecan-waffle.psm1"" -Global -DisableNameChecking
}
else{
    # try and load locally if possible from extension installdir    
    if( ($extensionInstallDir -ne $null) -and (Test-Path $extensionInstallDir)){
        # look for pecan-waffle and file-replacer modules and load them
        [System.IO.FileInfo]$npLocalModFile = ((Get-ChildItem $extensionInstallDir 'nuget-powershell.psd1' -Recurse -File)|Select-Object -First 1)
        [System.IO.FileInfo]$frLocalModFile = ((Get-ChildItem $extensionInstallDir 'file-replacer.psm1' -Recurse -File)|Select-Object -First 1)
        [System.IO.FileInfo]$pwLocalModFile = ((Get-ChildItem $extensionInstallDir 'pecan-waffle.psm1' -Recurse -File)|Select-Object -First 1)

        if( ($npLocalModFile -ne $null) -and (Test-Path $npLocalModFile.FullName)){
            Import-Module $npLocalModFile.FullName -Global -DisableNameChecking
        }
        else{
            throw ('nuget-powershell module not found at [{0}]' -f $npLocalModFile)
        }

        if( ($frLocalModFile -ne $null) -and (Test-Path $frLocalModFile.FullName)){
            Import-Module $frLocalModFile.FullName -Global -DisableNameChecking
            $foundFileReplacer = $true
        }
        else{
            throw ('file-replacer module not found at [{0}]' -f $frLocalModFile)
        }

        if( ($pwLocalModFile -ne $null) -and (Test-Path $pwLocalModFile.FullName)){
            Import-Module $pwLocalModFile.FullName -Global -DisableNameChecking
        }
        else{
            throw ('pecan-waffle module not found at [{0}]' -f $frLocalModFile)
        }
    }
    else{
        throw ('Unable to load pecan-waffle modules because extensionInstallDir is empty')
    }
}";
    }
}
