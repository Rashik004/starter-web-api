using Microsoft.Extensions.DependencyInjection;

namespace Starter.Responses;

/// <summary>
/// Registers the ApiResponseFilter in DI for opt-in use via
/// [ServiceFilter(typeof(ApiResponseFilter))]. Does NOT register the filter globally --
/// controllers opt in by applying the attribute.
/// </summary>
public static class ResponsesExtensions
{
    public static IServiceCollection AddAppResponses(this IServiceCollection services)
    {
        services.AddScoped<Filters.ApiResponseFilter>();
        return services;
    }
}
