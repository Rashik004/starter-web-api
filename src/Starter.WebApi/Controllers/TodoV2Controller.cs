using Asp.Versioning;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Starter.Shared.Contracts;
using Starter.Shared.Exceptions;
using Starter.WebApi.Models;

namespace Starter.WebApi.Controllers;

/// <summary>
/// Todo items API (v2). Returns expanded fields: priority, dueDate, tags.
/// </summary>
[ApiVersion(2.0)]
[ApiController]
[Route("api/v{version:apiVersion}/todos")]
[Authorize]
public class TodoV2Controller(ITodoService todoService) : ControllerBase
{
    /// <summary>
    /// Gets all todo items with expanded v2 fields.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<TodoItemV2Dto>>> GetAll(
        CancellationToken cancellationToken)
    {
        var items = await todoService.GetAllV2Async(cancellationToken);
        return Ok(items);
    }

    /// <summary>
    /// Gets a todo item by id with expanded v2 fields.
    /// </summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<TodoItemV2Dto>> GetById(
        int id, CancellationToken cancellationToken)
    {
        var item = await todoService.GetByIdV2Async(id, cancellationToken);
        return item is null ? NotFound() : Ok(item);
    }

    /// <summary>
    /// Creates a new todo item with v2 fields (priority, dueDate, tags).
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<TodoItemV2Dto>> Create(
        CreateTodoV2Request request,
        [FromServices] IValidator<CreateTodoV2Request> validator,
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

        var item = await todoService.CreateV2Async(
            request.Title, request.Priority, request.DueDate, request.Tags, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = item.Id, version = "2" }, item);
    }

    /// <summary>
    /// Updates an existing todo item with v2 fields.
    /// </summary>
    [HttpPut("{id:int}")]
    public async Task<ActionResult<TodoItemV2Dto>> Update(
        int id, UpdateTodoV2Request request,
        [FromServices] IValidator<UpdateTodoV2Request> validator,
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

        var item = await todoService.UpdateV2Async(
            id, request.Title, request.IsComplete, request.Priority,
            request.DueDate, request.Tags, cancellationToken);
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
