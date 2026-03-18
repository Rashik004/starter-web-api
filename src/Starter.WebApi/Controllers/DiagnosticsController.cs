using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Hosting;
using Starter.Shared.Exceptions;

namespace Starter.WebApi.Controllers;

/// <summary>
/// Development-only endpoints for testing the global exception handling pipeline.
/// Each endpoint throws a specific exception type to verify ProblemDetails mapping.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class DiagnosticsController(IHostEnvironment environment) : ControllerBase
{
    [HttpGet("not-found")]
    public IActionResult ThrowNotFound()
    {
        EnsureDevelopment();
        throw new NotFoundException("Entity with ID 42 was not found.");
    }

    [HttpGet("validation")]
    public IActionResult ThrowValidation()
    {
        EnsureDevelopment();
        var errors = new Dictionary<string, string[]>
        {
            { "Name", new[] { "Name is required.", "Name must be at least 3 characters." } },
            { "Price", new[] { "Price must be greater than zero." } }
        };
        throw new AppValidationException(errors);
    }

    [HttpGet("conflict")]
    public IActionResult ThrowConflict()
    {
        EnsureDevelopment();
        throw new ConflictException("An entity with that name already exists.");
    }

    [HttpGet("unauthorized")]
    public IActionResult ThrowUnauthorized()
    {
        EnsureDevelopment();
        throw new UnauthorizedException();
    }

    [HttpGet("forbidden")]
    public IActionResult ThrowForbidden()
    {
        EnsureDevelopment();
        throw new ForbiddenException();
    }

    [HttpGet("unhandled")]
    public IActionResult ThrowUnhandled()
    {
        EnsureDevelopment();
        throw new InvalidOperationException("Something unexpected happened.");
    }

    private void EnsureDevelopment()
    {
        if (!environment.IsDevelopment())
        {
            throw new ForbiddenException("Diagnostics endpoints are only available in Development.");
        }
    }
}
