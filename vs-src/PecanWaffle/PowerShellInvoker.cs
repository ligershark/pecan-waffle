namespace PecanWaffle {
    using System;
    using System.Collections;
    using System.Collections.Generic;
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

        public void EnsureInstallPwScriptInvoked(string pwInstallBranch, string extensionInstallDir) {
            PsInstance = PowerShell.Create();
            PsInstance.AddScript(_psInstallPecanWaffleScript);
            PsInstance.AddParameter("pwInstallBranch", pwInstallBranch);
            PsInstance.AddParameter("extensionInstallDir",extensionInstallDir);
            var result = PsInstance.Invoke();
            // WriteToOutputWindow(GetStringFrom(result));

            bool hadErrors = false;
            string errorString = null;
            var errorsb = new StringBuilder();
            if (PsInstance.HadErrors && PsInstance.Streams.Error.Count > 0) {
                var error = PsInstance.Streams.Error.ReadAll();
                if (error != null) {
                    foreach (var er in error) {
                        hadErrors = true;
                        errorsb.AppendLine(er.Exception.ToString());
                    }
                }

                if (hadErrors) {
                    errorString = errorsb.ToString();
                    // TODO: Improve this
                    MessageBox.Show(errorString.ToString());
                }
            }
        }
        public void RunPwCreateProjectScript(string projectName, string destPath, string templateName, string pwBranchName, string templateSource, string templateSourceBranch, Hashtable properties) {
            // EnsureInstallPwScriptInvoked(pwBranchName);

            bool hadErrors = false;
            string errorString = "";
            // here is where we want to call pecan-waffle
            try {
                var instance = PsInstance;
                PsInstance.AddScript(_psNewProjectScript);

                PsInstance.AddParameter("templateName", templateName);
                PsInstance.AddParameter("projectName", projectName);
                PsInstance.AddParameter("destPath", destPath);

                if (!string.IsNullOrWhiteSpace(pwBranchName)) {
                    PsInstance.AddParameter("pwInstallBranch", pwBranchName);
                }
                if (!string.IsNullOrWhiteSpace(templateSource)) {
                    PsInstance.AddParameter("TemplateSource", templateSource);
                }
                if (!string.IsNullOrWhiteSpace(templateSourceBranch)) {
                    PsInstance.AddParameter("TemplateSourceBranch", templateSourceBranch);
                }

                if (properties != null) {
                    PsInstance.AddParameter("Properties", properties);
                }

                var result = PsInstance.Invoke();
                // WriteToOutputWindow(GetStringFrom(result));
                var errorsb = new StringBuilder();
                if (PsInstance.HadErrors && PsInstance.Streams.Error.Count > 0) {
                    var error = PsInstance.Streams.Error.ReadAll();
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
            catch (Exception ex) {
                // TODO: Improve
                throw ex;
            }

            if (hadErrors) {
                // TODO: Improve
                throw new ApplicationException(errorString);
            }
        }

        private string _psNewProjectScript = @"
param($templateName,$projectname,$destpath,$pwInstallBranch,$templateSource,$templateSourceBranch,$properties)
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
param($pwInstallBranch, $extensionInstallDir)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted | out-null

$modLoaded = $false
$localPath = $env:PWLocalPath
if( (-not [string]::IsNullOrWhiteSpace($localPath)) -and (Test-Path $localPath)){
    Import-Module ""$localPath\pecan-waffle.psm1"" -Global -DisableNameChecking
    $modLoaded = $true
}
else{
    # try and load locally if possible from extension installdir    
    if( ($extensionInstallDir -ne $null) -and (Test-Path $extensionInstallDir)){
        $foundFileReplacer = $false
        $foundPecanWaffle = $false
        # look for pecan-waffle and file-replacer modules
        [System.IO.FileInfo]$pwLocalModFile = ((Get-ChildItem $extensionInstallDir 'pecan-waffle.psm1' -Recurse -File)|Select-Object -First 1)
        [System.IO.FileInfo]$frLocalModFile = ((Get-ChildItem $extensionInstallDir 'file-replacer.psm1' -Recurse -File)|Select-Object -First 1)

        if( ($frLocalModFile -ne $null) -and (Test-Path $frLocalModFile.FullName)){
            Import-Module $frLocalModFile.FullName -Global -DisableNameChecking
            $foundFileReplacer = $true
        }
        if( ($pwLocalModFile -ne $null) -and (Test-Path $pwLocalModFile.FullName)){
            Import-Module $pwLocalModFile.FullName -Global -DisableNameChecking
            $foundPecanWaffle = $true
        }

        if( ($foundFileReplacer -eq $true) -and ($foundPecanWaffle -eq $true)){
            $modLoaded = $true
        }
    }
}

if(-not $modLoaded){
    if([string]::IsNullOrWhiteSpace($pwInstallBranch)){ $pwInstallBranch = 'master' }

    $env:EnableAddLocalSourceOnLoad =$false

    # parameters declared here
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted | out-null

    [System.Version]$minPwVersion = (New-Object -TypeName 'system.version' -ArgumentList '0.0.2.0')
    $pwNeedsInstall = $true

    # see if pw is already installed and has a high enough version
    [System.Version]$installedVersion = $null
    try{
        Import-Module pecan-waffle -ErrorAction SilentlyContinue | out-null
        $installedVersion = Get-PecanWaffleVersion
    }
    catch{
        $installedVersion = $null
    }

    if( ($installedVersion -ne $null) -and ($installedVersion.CompareTo($minPwVersion) -ge 0)){
        $pwNeedsInstall = $false
    }

    $localPath = $env:PWLocalPath

    if( (-not [string]::IsNullOrWhiteSpace($localPath)) -and (Test-Path $localPath)){
        $pwNeedsInstall = $true
    }

    if($pwNeedsInstall){
        Remove-Module pecan-waffle -ErrorAction SilentlyContinue | Out-Null
    
        [System.IO.DirectoryInfo]$localInstallFolder = ""$env:USERPROFILE\Documents\WindowsPowerShell\Modules\pecan-waffle""
        if(test-path $localInstallFolder.FullName){
            Remove-Item $localInstallFolder.FullName -Recurse
        }
    
        if( (-not [string]::IsNullOrWhiteSpace($localPath)) -and (Test-Path $localPath)){
            Import-Module ""$localPath\pecan-waffle.psm1"" -Global -DisableNameChecking
        }
        else{
            $installUrl = ('https://raw.githubusercontent.com/ligershark/pecan-waffle/{0}/install.ps1' -f $pwInstallBranch)
            &{set-variable -name pwbranch -value $pwInstallBranch;$wc=New-Object System.Net.WebClient;$wc.Proxy=[System.Net.WebRequest]::DefaultWebProxy;$wc.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;Invoke-Expression ($wc.DownloadString($installUrl))}
        }
    }
}";
    }
}
