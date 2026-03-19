using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Starter.Data;

namespace Starter.WebApi.Tests.Integration;

/// <summary>
/// WebApplicationFactory that keeps the real authentication pipeline active (PolicyScheme + JWT + Identity).
/// Only overrides the database (SQLite in-memory) and configuration (test JWT secret).
/// Used exclusively by auth flow round-trip tests (TEST-03).
/// </summary>
public class AuthWebApplicationFactory : WebApplicationFactory<Program>
{
    private SqliteConnection? _connection;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureAppConfiguration((_, config) =>
        {
            config.AddJsonFile("appsettings.Testing.json", optional: true);
        });

        builder.ConfigureTestServices(services =>
        {
            // Remove production DB registrations
            var dbDescriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (dbDescriptor is not null) services.Remove(dbDescriptor);

            // Remove IDbContextOptionsConfiguration<> descriptors to prevent production DB conflicts
            var configDescriptors = services
                .Where(d => d.ServiceType.IsGenericType &&
                            d.ServiceType.GetGenericTypeDefinition() ==
                            typeof(IDbContextOptionsConfiguration<>))
                .ToList();
            foreach (var d in configDescriptors) services.Remove(d);

            // Create unique SQLite in-memory connection per factory instance
            _connection = new SqliteConnection("DataSource=:memory:");
            _connection.Open();

            services.AddDbContext<AppDbContext>(options =>
            {
                options.UseSqlite(_connection);
            });

            // Build temporary ServiceProvider to create/seed the database
            var sp = services.BuildServiceProvider();
            using var scope = sp.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Database.EnsureCreated();

            // NOTE: No fake auth handler registered here.
            // The real auth pipeline (PolicyScheme + JWT + Identity) remains active.
            // appsettings.Testing.json provides Jwt:SecretKey for token validation.
        });

        builder.UseEnvironment("Development");
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _connection?.Close();
            _connection?.Dispose();
        }

        base.Dispose(disposing);
    }
}
