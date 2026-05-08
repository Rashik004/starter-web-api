using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Starter.Shared.Responses;

namespace Starter.Responses.Filters;

/// <summary>
/// Wraps successful (2xx) ObjectResult responses in an ApiResponse envelope.
/// Applied per-controller/action via [ServiceFilter(typeof(ApiResponseFilter))].
/// Error responses (4xx/5xx) are NOT wrapped -- they use ProblemDetails from GlobalExceptionHandler.
/// </summary>
internal sealed class ApiResponseFilter : IResultFilter
{
    public void OnResultExecuting(ResultExecutingContext context)
    {
        if (context.Result is not ObjectResult objectResult)
            return;

        if (objectResult.Value is ApiResponse<object>)
            return;

        if (objectResult.StatusCode is not (>= 200 and < 300))
            return;

        if (objectResult.Value is null && objectResult.StatusCode is 204)
            return;

        context.Result = new ObjectResult(
            new ApiResponse<object>
            {
                Success = true,
                Data = objectResult.Value,
                Timestamp = DateTime.UtcNow
            })
        {
            StatusCode = objectResult.StatusCode
        };
    }

    public void OnResultExecuted(ResultExecutedContext context)
    {
    }
}
