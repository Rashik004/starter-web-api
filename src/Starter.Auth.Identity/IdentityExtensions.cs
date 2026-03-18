using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.DependencyInjection;
using Starter.Auth.Shared.Entities;
using Starter.Data;

namespace Starter.Auth.Identity;

public static class IdentityExtensions
{
    /// <summary>
    /// Registers ASP.NET Identity with AppUser backed by the EF Core AppDbContext store.
    /// Removing this module switches the app to JWT-only authentication.
    /// </summary>
    public static WebApplicationBuilder AddAppIdentity(this WebApplicationBuilder builder)
    {
        builder.Services.AddIdentity<AppUser, IdentityRole>(options =>
        {
            // Password policy -- relaxed for starter, tighten per your requirements
            options.Password.RequireDigit = true;
            options.Password.RequiredLength = 8;
            options.Password.RequireNonAlphanumeric = false;
            options.Password.RequireUppercase = true;
            options.Password.RequireLowercase = true;

            // Lockout
            options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
            options.Lockout.MaxFailedAccessAttempts = 5;
            options.Lockout.AllowedForNewUsers = true;

            // User
            options.User.RequireUniqueEmail = true;
        })
        .AddEntityFrameworkStores<AppDbContext>()
        .AddDefaultTokenProviders();

        return builder;
    }
}
