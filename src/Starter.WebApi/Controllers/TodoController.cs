using Microsoft.AspNetCore.Mvc;
using Starter.Shared.Contracts;
using Starter.WebApi.Models;

namespace Starter.WebApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TodoController(ITodoService todoService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<TodoItemDto>>> GetAll(
        CancellationToken cancellationToken)
    {
        var items = await todoService.GetAllAsync(cancellationToken);
        return Ok(items);
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<TodoItemDto>> GetById(
        int id, CancellationToken cancellationToken)
    {
        var item = await todoService.GetByIdAsync(id, cancellationToken);
        return item is null ? NotFound() : Ok(item);
    }

    [HttpPost]
    public async Task<ActionResult<TodoItemDto>> Create(
        CreateTodoRequest request, CancellationToken cancellationToken)
    {
        var item = await todoService.CreateAsync(request.Title, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = item.Id }, item);
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<TodoItemDto>> Update(
        int id, UpdateTodoRequest request, CancellationToken cancellationToken)
    {
        var item = await todoService.UpdateAsync(
            id, request.Title, request.IsComplete, cancellationToken);
        return item is null ? NotFound() : Ok(item);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(
        int id, CancellationToken cancellationToken)
    {
        var deleted = await todoService.DeleteAsync(id, cancellationToken);
        return deleted ? NoContent() : NotFound();
    }
}
