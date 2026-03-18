using Starter.Data.Entities;
using Starter.Shared.Contracts;
using Starter.Shared.Exceptions;

namespace Starter.Data.Services;

/// <summary>
/// Todo business logic layer. Maps between <see cref="TodoItem"/> entities and
/// <see cref="TodoItemDto"/> records, throws <see cref="NotFoundException"/> for missing items.
/// </summary>
internal sealed class TodoService(IRepository<TodoItem> repository) : ITodoService
{
    public async Task<TodoItemDto?> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var item = await repository.GetByIdAsync(id, cancellationToken);
        return item is null ? null : MapToDto(item);
    }

    public async Task<IReadOnlyList<TodoItemDto>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        var items = await repository.GetAllAsync(cancellationToken);
        return items.Select(MapToDto).ToList();
    }

    public async Task<TodoItemDto> CreateAsync(string title, CancellationToken cancellationToken = default)
    {
        var item = new TodoItem
        {
            Title = title,
            IsComplete = false,
            CreatedAt = DateTime.UtcNow
        };

        var created = await repository.AddAsync(item, cancellationToken);
        return MapToDto(created);
    }

    public async Task<TodoItemDto?> UpdateAsync(int id, string title, bool isComplete, CancellationToken cancellationToken = default)
    {
        var item = await repository.GetByIdAsync(id, cancellationToken);
        if (item is null)
            throw new NotFoundException($"TodoItem with id {id} not found");

        item.Title = title;
        item.IsComplete = isComplete;
        await repository.UpdateAsync(item, cancellationToken);
        return MapToDto(item);
    }

    public async Task<bool> DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var item = await repository.GetByIdAsync(id, cancellationToken);
        if (item is null) return false;

        await repository.DeleteAsync(item, cancellationToken);
        return true;
    }

    private static TodoItemDto MapToDto(TodoItem item)
        => new(item.Id, item.Title, item.IsComplete, item.CreatedAt);
}
