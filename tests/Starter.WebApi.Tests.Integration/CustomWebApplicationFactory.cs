using FluentValidation;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Serilog;
using Starter.Data;
using Starter.WebApi.Tests.Integration.Helpers;

namespace Starter.WebApi.Tests.Integration;

public class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    private SqliteConnection? _connection;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        // Reset Serilog to a fresh reloadable (bootstrap) logger so each factory instance
        // can freeze it. Without this, the second factory throws "The logger is already frozen"
        // because Serilog.Extensions.Hosting freezes the static Log.Logger on first host build.
        Log.Logger = new LoggerConfiguration()
            .MinimumLevel.Warning()
            .CreateBootstrapLogger();

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

            // Seed the database using a direct DbContext (not BuildServiceProvider,
            // which triggers Serilog Freeze() and breaks WebApplicationFactory host creation)
            var dbOptions = new DbContextOptionsBuilder<AppDbContext>()
                .UseSqlite(_connection)
                .Options;
            using (var db = new AppDbContext(dbOptions))
            {
                db.Database.EnsureCreated();
            }

            // Re-register FluentValidation validators from the Host assembly.
            // GetEntryAssembly() returns the test runner in WebApplicationFactory context,
            // so validators from Starter.WebApi are not discovered automatically.
            services.AddValidatorsFromAssemblyContaining<Program>(ServiceLifetime.Scoped);

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
