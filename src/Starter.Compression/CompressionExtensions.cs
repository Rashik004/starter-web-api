using System.IO.Compression;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.ResponseCompression;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Starter.Compression.Options;

namespace Starter.Compression;

public static class CompressionExtensions
{
    /// <summary>
    /// Registers response compression services with Brotli and Gzip providers.
    /// All settings are driven by the "Compression" configuration section.
    /// </summary>
    public static IServiceCollection AddAppCompression(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddOptions<CompressionModuleOptions>()
            .BindConfiguration(CompressionModuleOptions.SectionName)
            .ValidateDataAnnotations()
            .ValidateOnStart();

        var options = configuration
            .GetSection(CompressionModuleOptions.SectionName)
            .Get<CompressionModuleOptions>() ?? new();

        if (!Enum.TryParse<CompressionLevel>(options.BrotliLevel, out var brotliLevel))
        {
            brotliLevel = CompressionLevel.Fastest;
        }

        if (!Enum.TryParse<CompressionLevel>(options.GzipLevel, out var gzipLevel))
        {
            gzipLevel = CompressionLevel.Fastest;
        }

        services.AddResponseCompression(opts =>
        {
            opts.EnableForHttps = options.EnableForHttps;
            opts.Providers.Add<BrotliCompressionProvider>();
            opts.Providers.Add<GzipCompressionProvider>();
        });

        services.Configure<BrotliCompressionProviderOptions>(o => o.Level = brotliLevel);
        services.Configure<GzipCompressionProviderOptions>(o => o.Level = gzipLevel);

        return services;
    }

    /// <summary>
    /// Adds response compression middleware. Must be called BEFORE any middleware
    /// that writes response bodies.
    /// WARNING: Enabling compression over HTTPS exposes the app to CRIME/BREACH
    /// side-channel attacks. See <see cref="CompressionModuleOptions.EnableForHttps"/>.
    /// </summary>
    public static WebApplication UseAppCompression(this WebApplication app)
    {
        app.UseResponseCompression();
        return app;
    }
}
