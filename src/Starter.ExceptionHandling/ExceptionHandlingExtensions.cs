using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Starter.ExceptionHandling.Options;

namespace Starter.ExceptionHandling;

public static class ExceptionHandlingExtensions
{
    /// <summary>
    /// Registers global exception handling services including ProblemDetails
    /// and the typed exception handler.
    /// </summary>
    public static IServiceCollection AddAppExceptionHandling(
        this IServiceCollection services)
    {
        // Bind and validate options
        services.AddOptions<ExceptionHandlingOptions>()
            .BindConfiguration(ExceptionHandlingOptions.SectionName)
            .ValidateDataAnnotations()
            .ValidateOnStart();

        // Register ProblemDetails with traceId extension
        services.AddProblemDetails(options =>
        {
            options.CustomizeProblemDetails = context =>
            {
                context.ProblemDetails.Extensions["traceId"] =
                    context.HttpContext.TraceIdentifier;
            };
        });

        // Register the global exception handler
        services.AddExceptionHandler<Handlers.GlobalExceptionHandler>();

        return services;
    }

    /// <summary>
    /// Adds the global exception handling middleware to the pipeline.
    /// Must be called first in the middleware pipeline.
    /// </summary>
    public static WebApplication UseAppExceptionHandling(
        this WebApplication app)
    {
        app.UseExceptionHandler();
        return app;
    }
}
