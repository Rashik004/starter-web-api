using FluentAssertions;

namespace Starter.WebApi.Tests.Architecture;

public class DockerArtifactsTests
{
    private static readonly string RepoRoot = FindRepoRoot();

    [Fact]
    public void Dockerfile_exists_at_repo_root()
    {
        File.Exists(Path.Combine(RepoRoot, "Dockerfile"))
            .Should().BeTrue("Dockerfile must exist at repo root for `docker build .`");
    }

    [Fact]
    public void Dockerignore_exists_at_repo_root()
    {
        File.Exists(Path.Combine(RepoRoot, ".dockerignore"))
            .Should().BeTrue(".dockerignore must exist at repo root to keep build context small");
    }

    [Fact]
    public void EnvExample_exists_at_repo_root()
    {
        File.Exists(Path.Combine(RepoRoot, ".env.example"))
            .Should().BeTrue(".env.example must exist so manual users can copy it to .env");
    }

    [Fact]
    public void Docker_dir_has_at_least_one_compose_file()
    {
        var dockerDir = Path.Combine(RepoRoot, "docker");
        Directory.Exists(dockerDir).Should().BeTrue("docker/ directory must exist");

        // Accept either trimmed (compose.yaml) or pre-trim (compose.<provider>.yaml shards).
        var composeFiles = Directory.GetFiles(dockerDir, "compose*.yaml");
        composeFiles.Should().NotBeEmpty(
            "docker/ must contain at least one compose file — either compose.yaml (trimmed) or compose.<provider>.yaml shards (pre-trim)");
    }

    private static string FindRepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            // .slnx is in src/ — so check for src/*.WebApi.slnx
            var srcDir = Path.Combine(dir.FullName, "src");
            if (Directory.Exists(srcDir) && Directory.GetFiles(srcDir, "*.WebApi.slnx").Length > 0)
            {
                return dir.FullName;
            }
            dir = dir.Parent!;
        }
        throw new InvalidOperationException("Could not locate repo root (no src/*.WebApi.slnx found by walking up from test bin).");
    }
}
