namespace Starter.Shared.Responses;

/// <summary>
/// Standardized response envelope. Success responses carry Data; error responses carry
/// Error/Errors. Error paths use RFC 7807 ProblemDetails from GlobalExceptionHandler --
/// this envelope is for success paths only.
/// </summary>
public sealed class ApiResponse<T>
{
    public bool Success { get; init; }

    public T? Data { get; init; }

    public string? Error { get; init; }

    public IDictionary<string, string[]>? Errors { get; init; }

    public DateTime Timestamp { get; init; } = DateTime.UtcNow;
}
