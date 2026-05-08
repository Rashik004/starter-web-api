using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Starter.Auth.Shared.Constants;

namespace Starter.Auth.Shared;

public static class AuthSharedExtensions
{
    public static WebApplicationBuilder AddAppAuthShared(this WebApplicationBuilder builder)
    {
        builder.Services.AddAuthentication(options =>
        {
            options.DefaultScheme = AuthConstants.PolicyScheme;
            options.DefaultChallengeScheme = AuthConstants.PolicyScheme;
        })
        .AddPolicyScheme(AuthConstants.PolicyScheme, displayName: null, options =>
        {
            // Always forward to JWT — this is an API, not a cookie-based UI.
            // The JWT handler gracefully returns "no result" when no Bearer token
            // is present, which is correct for [AllowAnonymous] endpoints.
            options.ForwardDefaultSelector = _ => AuthConstants.JwtScheme;
        });

        builder.Services.AddAuthorization();

        return builder;
    }
}
