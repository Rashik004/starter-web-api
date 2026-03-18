using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Identity;
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
            options.ForwardDefaultSelector = context =>
            {
                string? authorization = context.Request.Headers.Authorization;
                if (!string.IsNullOrEmpty(authorization) &&
                    authorization.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
                {
                    return AuthConstants.JwtScheme;
                }
                return IdentityConstants.ApplicationScheme;
            };
        });

        builder.Services.AddAuthorization();

        return builder;
    }
}
