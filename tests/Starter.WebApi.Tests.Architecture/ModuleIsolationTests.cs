using System.Reflection;
using FluentAssertions;
using NetArchTest.Rules;
using Starter.Auth.Google;
using Starter.Auth.Identity;
using Starter.Auth.Jwt;
using Starter.Auth.Shared;
using Starter.Caching;
using Starter.Compression;
using Starter.Cors;
using Starter.Data;
using Starter.ExceptionHandling;
using Starter.HealthChecks;
using Starter.Logging;
using Starter.OpenApi;
using Starter.RateLimiting;
using Starter.Responses;
using Starter.Shared.Contracts;
using Starter.Validation;
using Starter.Versioning;

namespace Starter.WebApi.Tests.Architecture;

public class ModuleIsolationTests
{
    /// <summary>
    /// All module assemblies that should be independently removable.
    /// Each is referenced via its public extension class type.
    /// </summary>
    private static readonly Assembly[] ModuleAssemblies =
    [
        typeof(ExceptionHandlingExtensions).Assembly,
        typeof(LoggingExtensions).Assembly,
        typeof(AuthSharedExtensions).Assembly,
        typeof(IdentityExtensions).Assembly,
        typeof(JwtExtensions).Assembly,
        typeof(GoogleExtensions).Assembly,
        typeof(DataExtensions).Assembly,
        typeof(CorsExtensions).Assembly,
        typeof(VersioningExtensions).Assembly,
        typeof(ValidationExtensions).Assembly,
        typeof(OpenApiExtensions).Assembly,
        typeof(RateLimitingExtensions).Assembly,
        typeof(CachingExtensions).Assembly,
        typeof(CompressionExtensions).Assembly,
        typeof(ResponsesExtensions).Assembly,
        typeof(HealthChecksExtensions).Assembly,
    ];

    /// <summary>
    /// Shared namespaces that any module is allowed to depend on.
    /// Starter.Shared: contracts, exceptions, DTOs (pure abstractions).
    /// Starter.Auth.Shared: AppUser, AuthConstants, JwtOptions (shared auth infrastructure).
    /// </summary>
    private static readonly string[] SharedNamespaces =
    [
        "Starter.Shared",
        "Starter.Auth.Shared",
    ];

    /// <summary>
    /// Known allowed cross-module dependencies beyond the universal shared namespaces.
    /// These are intentional architectural choices, not violations:
    /// - Auth.Identity -> Data: needs AppDbContext for AddEntityFrameworkStores
    /// - HealthChecks -> Data: needs AppDbContext for AddDbContextCheck
    /// </summary>
    private static readonly Dictionary<string, string[]> AllowedModuleDependencies = new()
    {
        ["Starter.Auth.Identity"] = ["Starter.Data"],
        ["Starter.HealthChecks"] = ["Starter.Data"],
    };

    [Fact]
    public void Modules_ShouldNot_DependOnOtherModules()
    {
        var moduleNames = ModuleAssemblies
            .Select(a => a.GetName().Name!)
            .ToArray();

        foreach (var assembly in ModuleAssemblies)
        {
            var assemblyName = assembly.GetName().Name!;

            // Get any known allowed dependencies for this specific module
            var allowedDeps = AllowedModuleDependencies.GetValueOrDefault(assemblyName, []);

            // Build the list of forbidden dependencies: all module names
            // EXCEPT the current module itself, shared namespaces, and known allowed deps
            var forbiddenNamespaces = moduleNames
                .Where(n => n != assemblyName
                         && !SharedNamespaces.Contains(n)
                         && !allowedDeps.Contains(n))
                .ToArray();

            var result = Types.InAssembly(assembly)
                .ShouldNot()
                .HaveDependencyOnAny(forbiddenNamespaces)
                .GetResult();

            var failingTypes = result.FailingTypeNames ?? [];

            result.IsSuccessful.Should().BeTrue(
                $"{assemblyName} should not depend on other modules but found: {string.Join(", ", failingTypes)}");
        }
    }

    [Fact]
    public void SharedProject_ShouldNotDependOnAnyModule()
    {
        var sharedAssembly = typeof(ITodoService).Assembly;

        var moduleNames = ModuleAssemblies
            .Select(a => a.GetName().Name!)
            .ToArray();

        var result = Types.InAssembly(sharedAssembly)
            .ShouldNot()
            .HaveDependencyOnAny(moduleNames)
            .GetResult();

        var failingTypes = result.FailingTypeNames ?? [];

        result.IsSuccessful.Should().BeTrue(
            $"Starter.Shared should not depend on any module but found: {string.Join(", ", failingTypes)}");
    }
}
