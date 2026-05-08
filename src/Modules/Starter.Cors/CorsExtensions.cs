using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Starter.Cors.Options;

namespace Starter.Cors;

public static class CorsExtensions
{
    /// <summary>
    /// Registers CORS policies from the "Cors" configuration section.
    /// Development uses permissive origins; production uses explicit origins from config.
    /// </summary>
    public static WebApplicationBuilder AddAppCors(this WebApplicationBuilder builder)
    {
        builder.Services.AddOptions<CorsOptions>()
            .BindConfiguration(CorsOptions.SectionName)
            .ValidateDataAnnotations()
            .ValidateOnStart();

        var corsOptions = builder.Configuration
            .GetSection(CorsOptions.SectionName)
            .Get<CorsOptions>() ?? new CorsOptions();

        builder.Services.AddCors(options =>
        {
            options.AddDefaultPolicy(policy =>
            {
                if (corsOptions.AllowedOrigins.Length == 0 ||
                    corsOptions.AllowedOrigins.Contains("*"))
                {
                    policy.AllowAnyOrigin();
                }
                else
                {
                    policy.WithOrigins(corsOptions.AllowedOrigins);
                }

                policy.WithMethods(corsOptions.AllowedMethods);
                policy.WithHeaders(corsOptions.AllowedHeaders);

                if (corsOptions.AllowCredentials &&
                    !corsOptions.AllowedOrigins.Contains("*"))
                {
                    policy.AllowCredentials();
                }
            });
        });

        return builder;
    }
}
