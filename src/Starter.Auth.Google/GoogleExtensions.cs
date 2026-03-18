using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Starter.Auth.Google.Options;
using Starter.Auth.Shared.Constants;

namespace Starter.Auth.Google;

public static class GoogleExtensions
{
    /// <summary>
    /// Registers Google OAuth as an external authentication provider when credentials
    /// are configured. When Authentication:Google:ClientId or ClientSecret is empty,
    /// the Google handler is NOT registered and the app starts normally without
    /// Google login support.
    /// Removing this module entirely removes Google login without affecting JWT or Identity auth.
    /// </summary>
    public static WebApplicationBuilder AddAppGoogle(this WebApplicationBuilder builder)
    {
        // Bind options (no ValidateDataAnnotations/ValidateOnStart -- empty is valid)
        builder.Services.AddOptions<GoogleAuthOptions>()
            .BindConfiguration(GoogleAuthOptions.SectionName);

        var googleSection = builder.Configuration.GetSection(GoogleAuthOptions.SectionName);
        var clientId = googleSection.GetValue<string>("ClientId") ?? string.Empty;
        var clientSecret = googleSection.GetValue<string>("ClientSecret") ?? string.Empty;

        // Only register the Google authentication handler when credentials are present.
        // This makes Google auth truly optional at runtime -- the app starts and works
        // without Google credentials configured. Per AUTH-06 and CONTEXT.md locked decision.
        if (!string.IsNullOrWhiteSpace(clientId) && !string.IsNullOrWhiteSpace(clientSecret))
        {
            builder.Services.AddAuthentication()
                .AddGoogle(AuthConstants.GoogleScheme, options =>
                {
                    options.ClientId = clientId;
                    options.ClientSecret = clientSecret;
                    // Let the AuthController handle the callback and JWT issuance
                    options.CallbackPath = "/api/auth/google-callback";
                });
        }

        return builder;
    }
}
