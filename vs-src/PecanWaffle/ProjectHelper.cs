using NuGet;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Build.Evaluation;
using EnvDTE100;

namespace PecanWaffle {
    public class ProjectHelper {
        private const string PackagesSlash = @"packages\";
        private const string SlashPackagesSlash = @"\packages\";
        private const string Reference = "Reference";
        private const string HintPath = "HintPath";
        // taken from: https://github.com/ligershark/template-builder/blob/e801f5ef53a18739a3fb11b0c9b22d1e57bc00b5/src/TemplateBuilder/FixNuGetPackageHintPathsWizard.cs

        internal static void UpdatePackagesPathInProject(global::EnvDTE.Project project, Solution4 solution) {
            if (project == null) { throw new ArgumentNullException(nameof(project)); }
            if (solution == null) { throw new ArgumentNullException(nameof(solution)); }

            string solutionFilePath = solution.FileName;
            string projectFilePath = project.FileName;

            string projectDirectoryPath = Path.GetDirectoryName(projectFilePath);
            string solutionDirectoryPath = string.IsNullOrEmpty(solutionFilePath) ? projectDirectoryPath : Path.GetDirectoryName(solutionFilePath);
            string customPackagesDirectoryPath = ProjectHelper.GetCustomPackagesDirectoryPath(solutionDirectoryPath);

            string relativePackagesDirectoryPath = GetRelativePackagesDirectoryPath(
                projectDirectoryPath,
                solutionDirectoryPath,
                customPackagesDirectoryPath);

            // fix items
            bool hasChanged = false;
            Project buildProject = new Project(projectFilePath);
            foreach (ProjectMetadata metadata in buildProject.Items
                .Where(x => string.Equals(x.ItemType, Reference, StringComparison.OrdinalIgnoreCase))
                .SelectMany(x => x.Metadata)
                .Where(x => string.Equals(x.Name, HintPath, StringComparison.OrdinalIgnoreCase) &&
                    (x.UnevaluatedValue.StartsWith(PackagesSlash) || x.UnevaluatedValue.Contains(SlashPackagesSlash)))) {
                
                string newValue;
                if(FixPackagesString(metadata.UnevaluatedValue,customPackagesDirectoryPath,relativePackagesDirectoryPath,out newValue)) {
                    hasChanged = true;
                    metadata.UnevaluatedValue = newValue;
                }
            }

            if (hasChanged) {
                project.Save();
            }

            var projElement = Microsoft.Build.Construction.ProjectRootElement.Open(projectFilePath);
            bool hasChangedProjElement = false;

            // fix imports
            foreach(var import in projElement.Imports) {
                // check Project element
                string newProjValue;
                if(FixPackagesString(import.Project, customPackagesDirectoryPath,relativePackagesDirectoryPath,out newProjValue)) {
                    import.Project = newProjValue;
                    hasChangedProjElement = true;
                }

                // check Condition
                if (import.Condition != null && import.Condition.Length > 0) {
                    string newCondition;
                    if(FixPackagesString(import.Condition,customPackagesDirectoryPath,relativePackagesDirectoryPath,out newCondition)) {
                        import.Condition = newCondition;
                    }
                }                
            }
            // fix error tasks
            var errorTasks = from t in projElement.Targets
                               from task in t.Tasks
                               where string.Equals("Error", task.Name, StringComparison.OrdinalIgnoreCase)
                               select task;

            foreach(var error in errorTasks) {
                string condStr;
                if(FixPackagesString(error.Condition,customPackagesDirectoryPath,relativePackagesDirectoryPath,out condStr)) {
                    error.Condition = condStr;
                    hasChangedProjElement = true;
                }

                // TODO: How to update the Text attribute on the Error task?
                //string textStr;
                //if (FixPackagesString(error.Condition, customPackagesDirectoryPath, relativePackagesDirectoryPath, out condStr)) {
                //    error.Condition = condStr;
                //    hasChangedProjElement = true;
                //}
            }
            

            if (hasChangedProjElement) {
                var existingProjects = new List<EnvDTE.Project>();
                foreach(global::EnvDTE.Project proj in solution.Projects) {
                    if (string.Equals(project.Name, proj.Name, StringComparison.OrdinalIgnoreCase)) {
                        solution.Remove(proj);
                    }
                    else {
                        existingProjects.Add(proj);
                    }
                }

                solution.Close(false);
                if (File.Exists(solutionFilePath)) {
                    solution.Open(solutionFilePath);
                }
                else {
                    var slnFileInfo = new FileInfo(solutionFilePath);
                    solution.Create(solutionFilePath, slnFileInfo.Name);
                }

                foreach(EnvDTE.Project proj in existingProjects) {
                    // see if it's already in the solution and if not add it
                    bool hasProject = false;
                    foreach(EnvDTE.Project p in solution.Projects) {
                        if (string.Equals(proj.Name, p.Name, StringComparison.OrdinalIgnoreCase)) {
                            hasChanged = true;
                            break;
                        }
                    }

                    if (!hasProject) {
                        solution.AddFromFile(proj.FileName, false);
                    }
                }

                solution = solution.DTE.Solution as Solution4;

                projElement.Save();
                solution.AddFromFile(projectFilePath, false);
            }
        }
        internal static bool FixPackagesString(string packagesString, string customPackagesDirectoryPath, string relativePackagesDirectoryPath, out string newPackagesString) {
            if (string.IsNullOrEmpty(packagesString)) { throw new ArgumentNullException(nameof(packagesString)); }

            bool hasChanged = false;
            
            var pkgRegex = new System.Text.RegularExpressions.Regex(@"[\.\\/]+packages");
            newPackagesString = pkgRegex.Replace(packagesString, relativePackagesDirectoryPath + "packages");

            if (!string.Equals(packagesString, newPackagesString, StringComparison.OrdinalIgnoreCase)) {
                hasChanged = true;
            }

            return hasChanged;
        }
        internal static string GetRelativePackagesDirectoryPath(
            string projectDirectoryPath,
            string solutionDirectoryPath,
            string customPackagesDirectoryPath) {
            string relativePackagesDirectoryPath;
            if (customPackagesDirectoryPath == null) {
                relativePackagesDirectoryPath = GetRelativePath(
                    projectDirectoryPath,
                    solutionDirectoryPath);
            }
            else {
                // Absolute Custom Packages Path
                if (Path.IsPathRooted(customPackagesDirectoryPath)) {
                    return GetRelativePath(projectDirectoryPath, customPackagesDirectoryPath);
                }

                // Relative Custom Packages Path
                string path = Path.Combine(solutionDirectoryPath, customPackagesDirectoryPath);
                return GetRelativePath(projectDirectoryPath, path);
            }

            return relativePackagesDirectoryPath;
        }

        /// <summary>
        /// Creates a relative path from one file or folder to another.
        /// </summary>
        /// <param name="fromPath">Contains the directory that defines the start of the relative path.</param>
        /// <param name="toPath">Contains the path that defines the endpoint of the relative path.</param>
        /// <returns>The relative path from the start directory to the end path.</returns>
        /// <exception cref="ArgumentNullException"><paramref name="fromPath"/> or <paramref name="toPath"/> is <c>null</c>.</exception>
        /// <exception cref="UriFormatException"></exception>
        /// <exception cref="InvalidOperationException"></exception>
        internal static string GetRelativePath(string fromPath, string toPath) {
            if (string.IsNullOrEmpty(fromPath)) {
                throw new ArgumentNullException("fromPath");
            }

            if (string.IsNullOrEmpty(toPath)) {
                throw new ArgumentNullException("toPath");
            }

            Uri fromUri = new Uri(AppendDirectorySeparatorChar(fromPath));
            Uri toUri = new Uri(AppendDirectorySeparatorChar(toPath));

            if (fromUri.Scheme != toUri.Scheme) {
                return toPath;
            }

            Uri relativeUri = fromUri.MakeRelativeUri(toUri);
            string relativePath = Uri.UnescapeDataString(relativeUri.ToString());

            if (string.Equals(toUri.Scheme, Uri.UriSchemeFile, StringComparison.OrdinalIgnoreCase)) {
                relativePath = relativePath.Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar);
            }

            return relativePath;
        }

        internal static string AppendDirectorySeparatorChar(string directoryPath) {
            if (!Path.HasExtension(directoryPath) &&
                !directoryPath.EndsWith(Path.DirectorySeparatorChar.ToString())) {
                return directoryPath + Path.DirectorySeparatorChar;
            }

            return directoryPath;
        }

        internal static string GetCustomPackagesDirectoryPath(string projectDirectoryPath) {
            // Read the nuget.config file and use the repository path there instead.
            // This is actually very complicated. See https://docs.nuget.org/consume/nuget-config-file
            // <?xml version="1.0" encoding="utf-8"?>
            // <configuration>
            //   <config>
            //     <add key="repositorypath" value="c:\blah" />
            //   </config>
            // </configuration>

            string rootPath = Path.GetPathRoot(projectDirectoryPath);
            IFileSystem fileSystem = new PhysicalFileSystem(rootPath);
            var settings = Settings.LoadMachineWideSettings(fileSystem, projectDirectoryPath);
            return settings.Select(x => x.GetRepositoryPath()).Where(x => x != null).FirstOrDefault();
        }


    }
}
