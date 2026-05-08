using Microsoft.AspNetCore.Mvc;

namespace Starter.Responses.Attributes;

/// <summary>
/// Apply to a controller or action to wrap successful responses in an ApiResponse envelope.
/// The underlying ApiResponseFilter is resolved from DI -- requires AddAppResponses() in Program.cs.
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public sealed class WrapResponseAttribute : ServiceFilterAttribute
{
    public WrapResponseAttribute() : base(typeof(Filters.ApiResponseFilter)) { }
}
