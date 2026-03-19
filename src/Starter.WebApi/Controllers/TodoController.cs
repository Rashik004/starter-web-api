using Asp.Versioning;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Starter.Responses.Attributes;
using Starter.Shared.Contracts;
using Starter.Shared.Exceptions;
using Starter.WebApi.Models;

namespace Starter.WebApi.Controllers;

/// <summary>
/// Todo items API (v1). Returns basic todo fields.
/// </summary>
[ApiVersion(1.0)]
[ApiController]
[Route("api/v{version:apiVersion}/todos")]
[Authorize]
[EnableRateLimiting("fixed")]
[WrapResponse]
public class TodoController(ITodoService todoService) : ControllerBase
{
    /// <summary>
    /// Gets all todo items.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<TodoItemDto>>> GetAll(
        CancellationToken cancellationToken)
    {
        var items = await todoService.GetAllAsync(cancellationToken);
        return Ok(items);
    }

    /// <summary>
    /// Gets a todo item by id.
    /// </summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<TodoItemDto>> GetById(
        int id, CancellationToken cancellationToken)
    {
        var item = await todoService.GetByIdAsync(id, cancellationToken);
        return item is null ? NotFound() : Ok(item);
    }

    /// <summary>
    /// Creates a new todo item.
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<TodoItemDto>> Create(
        CreateTodoRequest request,
        [FromServices] IValidator<CreateTodoRequest> validator,
        CancellationToken cancellationToken)
    {
        var validationResult = await validator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            var errors = validationResult.Errors
                .GroupBy(e => e.PropertyName)
                .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray());
            throw new AppValidationException(errors);
        }

        var item = await todoService.CreateAsync(request.Title, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = item.Id, version = "1" }, item);
    }

    /// <summary>
    /// Updates an existing todo item.
    /// </summary>
    [HttpPut("{id:int}")]
    public async Task<ActionResult<TodoItemDto>> Update(
        int id, UpdateTodoRequest request,
        [FromServices] IValidator<UpdateTodoRequest> validator,
        CancellationToken cancellationToken)
    {
        var validationResult = await validator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            var errors = validationResult.Errors
                .GroupBy(e => e.PropertyName)
                .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray());
            throw new AppValidationException(errors);
        }

        var item = await todoService.UpdateAsync(
            id, request.Title, request.IsComplete, cancellationToken);
        return item is null ? NotFound() : Ok(item);
    }

    /// <summary>
    /// Deletes a todo item.
    /// </summary>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(
        int id, CancellationToken cancellationToken)
    {
        var deleted = await todoService.DeleteAsync(id, cancellationToken);
        return deleted ? NoContent() : NotFound();
    }
}
