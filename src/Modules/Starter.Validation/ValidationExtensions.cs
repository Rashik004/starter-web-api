using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.DependencyInjection;

namespace Starter.Validation;

public static class ValidationExtensions
{
    /// <summary>
    /// Registers FluentValidation validators from the calling assembly (Host project)
    /// and suppresses the built-in MVC DataAnnotations auto-validation so FluentValidation
    /// is the single validation source. Validators are injected as IValidator&lt;T&gt; and
    /// invoked manually in controllers.
    /// </summary>
    public static IServiceCollection AddAppValidation(this IServiceCollection services)
    {
        // Scan entry assembly for validators (controllers and request models live there)
        var entryAssembly = System.Reflection.Assembly.GetEntryAssembly();
        if (entryAssembly is not null)
        {
            services.AddValidatorsFromAssembly(entryAssembly, ServiceLifetime.Scoped);
        }

        // Suppress MVC auto-validation so FluentValidation is the single source
        // (prevents duplicate validation from DataAnnotations + FluentValidation)
        services.Configure<ApiBehaviorOptions>(options =>
            options.SuppressModelStateInvalidFilter = true);

        return services;
    }
}
