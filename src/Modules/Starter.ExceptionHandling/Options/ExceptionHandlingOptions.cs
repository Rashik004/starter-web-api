using System.ComponentModel.DataAnnotations;

namespace Starter.ExceptionHandling.Options;

public sealed class ExceptionHandlingOptions
{
    public const string SectionName = "ExceptionHandling";

    /// <summary>
    /// Whether to include stack traces in ProblemDetails responses when running in Development.
    /// Default: true.
    /// </summary>
    public bool IncludeStackTraceInDevelopment { get; set; } = true;
}
