using System.Diagnostics;
using System.Reflection;
using System.Runtime.InteropServices;
using FluentAssertions;

namespace Starter.WebApi.Tests.Architecture;

public class ModuleRemovalTests
{
    /// <summary>
    /// Finds the solution root by walking up from the test assembly location
    /// until we find the Starter.WebApi.slnx file.
    /// </summary>
    private static string GetSolutionRoot()
    {
        var assemblyDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location)!;
        var dir = new DirectoryInfo(assemblyDir);

        while (dir != null)
        {
            if (dir.GetFiles("Starter.WebApi.slnx").Length > 0)
            {
                return dir.FullName;
            }
            dir = dir.Parent;
        }

        throw new InvalidOperationException(
            $"Could not find solution root from {assemblyDir}. " +
            "Ensure the test is run from within the solution directory structure.");
    }

    /// <summary>
    /// Gets the path to the test-module-removal script appropriate for the current OS.
    /// </summary>
    private static string GetScriptPath()
    {
        var solutionRoot = GetSolutionRoot();
        var scriptsDir = Path.Combine(solutionRoot, "tests", "Starter.WebApi.Tests.Architecture", "Scripts");

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            return Path.Combine(scriptsDir, "test-module-removal.ps1");
        }

        return Path.Combine(scriptsDir, "test-module-removal.sh");
    }

    [Fact]
    public void ScriptExists()
    {
        var solutionRoot = GetSolutionRoot();
        var scriptsDir = Path.Combine(solutionRoot, "tests", "Starter.WebApi.Tests.Architecture", "Scripts");

        var ps1Path = Path.Combine(scriptsDir, "test-module-removal.ps1");
        var shPath = Path.Combine(scriptsDir, "test-module-removal.sh");

        File.Exists(ps1Path).Should().BeTrue($"PowerShell script should exist at {ps1Path}");
        File.Exists(shPath).Should().BeTrue($"Bash script should exist at {shPath}");
    }

    [Fact]
    [Trait("Category", "Slow")]
    public void AllModules_CanBeRemovedIndependently_BuildSucceeds()
    {
        var scriptPath = GetScriptPath();
        var solutionRoot = GetSolutionRoot();

        File.Exists(scriptPath).Should().BeTrue($"Script should exist at {scriptPath}");

        var psi = new ProcessStartInfo
        {
            WorkingDirectory = solutionRoot,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            psi.FileName = "pwsh";
            psi.Arguments = $"-ExecutionPolicy Bypass -File \"{scriptPath}\"";
        }
        else
        {
            psi.FileName = "bash";
            psi.Arguments = $"\"{scriptPath}\"";
        }

        using var process = Process.Start(psi);
        process.Should().NotBeNull("script process should start successfully");

        var stdout = process!.StandardOutput.ReadToEnd();
        var stderr = process.StandardError.ReadToEnd();

        // Wait up to 10 minutes (19 builds take time)
        var exited = process.WaitForExit(TimeSpan.FromMinutes(10));

        exited.Should().BeTrue("script should complete within 10 minutes");

        var exitCode = process.ExitCode;

        exitCode.Should().Be(0,
            $"all module removal builds should succeed.\n\n" +
            $"--- STDOUT ---\n{stdout}\n\n" +
            $"--- STDERR ---\n{stderr}");
    }
}
