using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using Starter.Auth.Jwt.Services;
using Starter.Auth.Shared.Options;

namespace Starter.Auth.Jwt;

public static class JwtExtensions
{
    /// <summary>
    /// Registers JWT Bearer token validation and the JwtTokenService for token generation.
    /// Removing this module switches the app to cookie/Identity-only authentication.
    /// </summary>
    public static WebApplicationBuilder AddAppJwt(this WebApplicationBuilder builder)
    {
        // Bind and validate JWT options
        builder.Services.AddOptions<JwtOptions>()
            .BindConfiguration(JwtOptions.SectionName)
            .ValidateDataAnnotations()
            .ValidateOnStart();

        var jwtSection = builder.Configuration.GetSection(JwtOptions.SectionName);
        var secretKey = jwtSection.GetValue<string>("SecretKey") ?? string.Empty;
        var issuer = jwtSection.GetValue<string>("Issuer") ?? string.Empty;
        var audience = jwtSection.GetValue<string>("Audience") ?? string.Empty;

        builder.Services.AddAuthentication()
            .AddJwtBearer(JwtBearerDefaults.AuthenticationScheme, options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(
                        Encoding.UTF8.GetBytes(secretKey)),
                    ValidateIssuer = true,
                    ValidIssuer = issuer,
                    ValidateAudience = true,
                    ValidAudience = audience,
                    ValidateLifetime = true,
                    ClockSkew = TimeSpan.FromMinutes(1)
                };
            });

        builder.Services.AddScoped<JwtTokenService>();

        return builder;
    }
}
