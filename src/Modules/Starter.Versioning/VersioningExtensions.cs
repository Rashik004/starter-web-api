using Asp.Versioning;
using Microsoft.Extensions.DependencyInjection;

namespace Starter.Versioning;

public static class VersioningExtensions
{
    /// <summary>
    /// Registers API versioning with URL segment strategy (/api/v1/, /api/v2/).
    /// </summary>
    public static IServiceCollection AddAppVersioning(this IServiceCollection services)
    {
        services.AddApiVersioning(options =>
        {
            options.DefaultApiVersion = new ApiVersion(1, 0);
            options.AssumeDefaultVersionWhenUnspecified = false;
            options.ReportApiVersions = true;
            options.ApiVersionReader = new UrlSegmentApiVersionReader();
        })
        .AddMvc()
        .AddApiExplorer(options =>
        {
            options.GroupNameFormat = "'v'VVV";
            options.SubstituteApiVersionInUrl = true;
        });

        return services;
    }
}
