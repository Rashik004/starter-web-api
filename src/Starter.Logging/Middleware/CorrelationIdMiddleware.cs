using Microsoft.AspNetCore.Http;

namespace Starter.Logging.Middleware;

/// <summary>
/// Copies the <c>X-Correlation-Id</c> request header into <see cref="HttpContext.TraceIdentifier"/>
/// so that both Serilog log entries and ProblemDetails error responses share the same correlation value.
/// </summary>
internal sealed class CorrelationIdMiddleware
{
    private const string CorrelationIdHeader = "X-Correlation-Id";
    private readonly RequestDelegate _next;

    public CorrelationIdMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context)
    {
        if (context.Request.Headers.TryGetValue(CorrelationIdHeader, out var correlationId)
            && !string.IsNullOrWhiteSpace(correlationId))
        {
            context.TraceIdentifier = correlationId!;
        }

        await _next(context);
    }
}
