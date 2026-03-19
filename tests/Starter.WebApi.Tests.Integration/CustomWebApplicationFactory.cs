using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Starter.Data;
using Starter.WebApi.Tests.Integration.Helpers;

namespace Starter.WebApi.Tests.Integration;

public class CustomWebApplicationFactory : WebApplicationFactory<Program>
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
            // Must stay open for the lifetime of the factory (Pitfall 2)
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

            // Override authentication: bypass PolicyScheme ForwardDefaultSelector (Pitfall 4)
            services.AddAuthentication(options =>
            {
                options.DefaultAuthenticateScheme = TestConstants.TestScheme;
                options.DefaultChallengeScheme = TestConstants.TestScheme;
            })
            .AddScheme<AuthenticationSchemeOptions, FakeAuthHandler>(
                TestConstants.TestScheme, _ => { });
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
