using Microsoft.Extensions.Configuration;
using Serilog;
using Serilog.Sinks.OpenTelemetry;

namespace Starter.Logging.Configuration;

/// <summary>
/// Conditionally registers Serilog sinks based on per-sink Enabled flags
/// read from the Serilog:Sinks configuration section.
/// </summary>
internal static class SinkRegistrar
{
    /// <summary>
    /// Reads sink configuration from <c>Serilog:Sinks</c> and registers each sink
    /// whose <c>Enabled</c> flag is <c>true</c>.
    /// </summary>
    internal static LoggerConfiguration ConfigureSinks(
        this LoggerConfiguration loggerConfig,
        IConfiguration configuration)
    {
        var sinksSection = configuration.GetSection("Serilog:Sinks");

        if (sinksSection.GetValue<bool>("Console:Enabled"))
        {
            var outputTemplate = sinksSection.GetValue<string>("Console:OutputTemplate")
                ?? "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}";
            loggerConfig.WriteTo.Console(outputTemplate: outputTemplate);
        }

        if (sinksSection.GetValue<bool>("File:Enabled"))
        {
            var path = sinksSection.GetValue<string>("File:Path") ?? "Logs/log-.txt";
            var rollingInterval = Enum.TryParse<RollingInterval>(
                sinksSection.GetValue<string>("File:RollingInterval"), out var interval)
                ? interval : RollingInterval.Day;
            var retainedFileCountLimit = sinksSection.GetValue<int?>("File:RetainedFileCountLimit") ?? 31;
            var fileSizeLimitBytes = sinksSection.GetValue<long?>("File:FileSizeLimitBytes") ?? 104857600;
            loggerConfig.WriteTo.File(
                path: path,
                rollingInterval: rollingInterval,
                retainedFileCountLimit: retainedFileCountLimit,
                fileSizeLimitBytes: fileSizeLimitBytes);
        }

        if (sinksSection.GetValue<bool>("Seq:Enabled"))
        {
            var serverUrl = sinksSection.GetValue<string>("Seq:ServerUrl") ?? "http://localhost:5341";
            loggerConfig.WriteTo.Seq(serverUrl);
        }

        if (sinksSection.GetValue<bool>("OpenTelemetry:Enabled"))
        {
            var endpoint = sinksSection.GetValue<string>("OpenTelemetry:Endpoint") ?? "http://localhost:4317";
            var protocol = sinksSection.GetValue<string>("OpenTelemetry:Protocol") ?? "Grpc";
            loggerConfig.WriteTo.OpenTelemetry(options =>
            {
                options.Endpoint = endpoint;
                options.Protocol = protocol.Equals("HttpProtobuf", StringComparison.OrdinalIgnoreCase)
                    ? OtlpProtocol.HttpProtobuf
                    : OtlpProtocol.Grpc;
            });
        }

        return loggerConfig;
    }
}
