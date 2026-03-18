using Microsoft.AspNetCore.Builder;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Starter.Data.Options;
using Starter.Data.Repositories;
using Starter.Data.Services;
using Starter.Shared.Contracts;

namespace Starter.Data;

public static class DataExtensions
{
    // Migration assembly names must match project names. Marker classes in each
    // assembly provide typeof(Marker).Assembly resolution for dotnet-ef tooling;
    // here we use constants to avoid circular project references.
    private const string SqliteMigrations = "Starter.Data.Migrations.Sqlite";
    private const string SqlServerMigrations = "Starter.Data.Migrations.SqlServer";
    private const string PostgreSqlMigrations = "Starter.Data.Migrations.PostgreSql";

    /// <summary>
    /// Registers EF Core data services with multi-provider support.
    /// Provider is selected via <c>Database:Provider</c> configuration value.
    /// </summary>
    public static WebApplicationBuilder AddAppData(this WebApplicationBuilder builder)
    {
        // Bind and validate database options
        builder.Services.AddOptions<DatabaseOptions>()
            .BindConfiguration(DatabaseOptions.SectionName)
            .ValidateDataAnnotations()
            .ValidateOnStart();

        var dbOptions = builder.Configuration
            .GetSection(DatabaseOptions.SectionName)
            .Get<DatabaseOptions>()!;

        builder.Services.AddDbContext<AppDbContext>((sp, options) =>
        {
            switch (dbOptions.Provider)
            {
                case "Sqlite":
                    options.UseSqlite(
                        builder.Configuration.GetConnectionString("Sqlite"),
                        x =>
                        {
                            x.MigrationsAssembly(SqliteMigrations);
                            if (dbOptions.CommandTimeout > 0)
                                x.CommandTimeout(dbOptions.CommandTimeout);
                        });
                    break;

                case "SqlServer":
                    options.UseSqlServer(
                        builder.Configuration.GetConnectionString("SqlServer"),
                        x =>
                        {
                            x.MigrationsAssembly(SqlServerMigrations);
                            x.EnableRetryOnFailure(
                                maxRetryCount: dbOptions.MaxRetryCount,
                                maxRetryDelay: TimeSpan.FromSeconds(30),
                                errorNumbersToAdd: null);
                            if (dbOptions.CommandTimeout > 0)
                                x.CommandTimeout(dbOptions.CommandTimeout);
                        });
                    break;

                case "PostgreSql":
                    options.UseNpgsql(
                        builder.Configuration.GetConnectionString("PostgreSql"),
                        x =>
                        {
                            x.MigrationsAssembly(PostgreSqlMigrations);
                            x.EnableRetryOnFailure(
                                maxRetryCount: dbOptions.MaxRetryCount,
                                maxRetryDelay: TimeSpan.FromSeconds(30),
                                errorCodesToAdd: null);
                            if (dbOptions.CommandTimeout > 0)
                                x.CommandTimeout(dbOptions.CommandTimeout);
                        });
                    break;

                default:
                    throw new InvalidOperationException(
                        $"Unsupported database provider: {dbOptions.Provider}. Valid values: Sqlite, SqlServer, PostgreSql");
            }

            if (dbOptions.EnableSensitiveDataLogging)
                options.EnableSensitiveDataLogging();
        });

        builder.Services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));
        builder.Services.AddScoped<ITodoService, TodoService>();

        return builder;
    }

    /// <summary>
    /// Applies pending EF Core migrations on startup when <c>Database:AutoMigrate</c> is true.
    /// </summary>
    public static WebApplication UseAppData(this WebApplication app)
    {
        var options = app.Configuration
            .GetSection(DatabaseOptions.SectionName)
            .Get<DatabaseOptions>();

        if (options?.AutoMigrate == true)
        {
            using var scope = app.Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Database.Migrate();
        }

        return app;
    }
}
