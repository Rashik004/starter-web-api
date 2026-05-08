using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Starter.ExceptionHandling.Options;
using Starter.Shared.Exceptions;

namespace Starter.ExceptionHandling.Handlers;

internal sealed class GlobalExceptionHandler(
    ILogger<GlobalExceptionHandler> logger,
    IHostEnvironment environment,
    IOptions<ExceptionHandlingOptions> options) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        // Log the exception BEFORE returning true (per .NET 10 SuppressDiagnosticsCallback behavior)
        logger.LogError(exception, "Unhandled exception: {Message}", exception.Message);

        var (statusCode, title) = MapException(exception);

        var problemDetails = new ProblemDetails
        {
            Status = statusCode,
            Title = title,
            Detail = exception.Message,
            Instance = $"{httpContext.Request.Method} {httpContext.Request.Path}",
            Type = $"https://httpstatuses.io/{statusCode}"
        };

        problemDetails.Extensions["traceId"] = httpContext.TraceIdentifier;

        if (environment.IsDevelopment() && options.Value.IncludeStackTraceInDevelopment)
        {
            problemDetails.Extensions["stackTrace"] = exception.StackTrace;
        }

        if (exception is AppValidationException validationException
            && validationException.Errors.Count > 0)
        {
            problemDetails.Extensions["errors"] = validationException.Errors;
        }

        httpContext.Response.StatusCode = statusCode;
        await httpContext.Response.WriteAsJsonAsync(problemDetails, cancellationToken);

        return true;
    }

    private static (int StatusCode, string Title) MapException(Exception exception) =>
        exception switch
        {
            NotFoundException => (StatusCodes.Status404NotFound, "Not Found"),
            AppValidationException => (StatusCodes.Status422UnprocessableEntity, "Validation Failed"),
            ConflictException => (StatusCodes.Status409Conflict, "Conflict"),
            UnauthorizedException => (StatusCodes.Status401Unauthorized, "Unauthorized"),
            ForbiddenException => (StatusCodes.Status403Forbidden, "Forbidden"),
            _ => (StatusCodes.Status500InternalServerError, "Internal Server Error")
        };
}
