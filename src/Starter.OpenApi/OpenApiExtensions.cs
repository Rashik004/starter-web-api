using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Scalar.AspNetCore;
using Starter.OpenApi.Options;
using Starter.OpenApi.Transformers;

namespace Starter.OpenApi;

public static class OpenApiExtensions
{
    /// <summary>
    /// Registers OpenAPI 3.1 document generation for each API version (v1, v2)
    /// with the Bearer security scheme transformer for Scalar JWT authorize support.
    /// </summary>
    public static WebApplicationBuilder AddAppOpenApi(this WebApplicationBuilder builder)
    {
        builder.Services.AddOptions<OpenApiOptions>()
            .BindConfiguration(OpenApiOptions.SectionName)
            .ValidateDataAnnotations()
            .ValidateOnStart();

        // Register separate OpenAPI documents per version.
        // Document names ("v1", "v2") MUST match the GroupNameFormat "'v'VVV" output
        // from Starter.Versioning so versioned endpoints appear in the correct document.
        builder.Services.AddOpenApi("v1", options =>
        {
            options.AddDocumentTransformer<BearerSecuritySchemeTransformer>();
        });

        builder.Services.AddOpenApi("v2", options =>
        {
            options.AddDocumentTransformer<BearerSecuritySchemeTransformer>();
        });

        return builder;
    }

    /// <summary>
    /// Maps the OpenAPI endpoints and optionally enables Scalar interactive documentation UI
    /// based on the OpenApi:EnableScalar configuration flag.
    /// </summary>
    public static WebApplication UseAppOpenApi(this WebApplication app)
    {
        app.MapOpenApi();

        var openApiOptions = app.Configuration
            .GetSection(OpenApiOptions.SectionName)
            .Get<OpenApiOptions>() ?? new OpenApiOptions();

        if (openApiOptions.EnableScalar)
        {
            app.MapScalarApiReference(options =>
            {
                options.Title = openApiOptions.Title;
                options
                    .AddDocument("v1", "API v1")
                    .AddDocument("v2", "API v2");
            });
        }

        return app;
    }
}
