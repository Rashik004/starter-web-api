using Starter.Data.Entities;
using Starter.Shared.Contracts;
using Starter.Shared.Exceptions;

namespace Starter.Data.Services;

/// <summary>
/// Todo service. Stub implementation -- full logic in Plan 02.
/// </summary>
internal sealed class TodoService(IRepository<TodoItem> repository) : ITodoService
{
    public async Task<TodoItemDto?> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var entity = await repository.GetByIdAsync(id, cancellationToken);
        return entity is null ? null : ToDto(entity);
    }

    public async Task<IReadOnlyList<TodoItemDto>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        var entities = await repository.GetAllAsync(cancellationToken);
        return entities.Select(ToDto).ToList();
    }

    public async Task<TodoItemDto> CreateAsync(string title, CancellationToken cancellationToken = default)
    {
        var entity = new TodoItem
        {
            Title = title,
            IsComplete = false,
            CreatedAt = DateTime.UtcNow
        };

        await repository.AddAsync(entity, cancellationToken);
        return ToDto(entity);
    }

    public async Task<TodoItemDto?> UpdateAsync(int id, string title, bool isComplete, CancellationToken cancellationToken = default)
    {
        var entity = await repository.GetByIdAsync(id, cancellationToken);
        if (entity is null) return null;

        entity.Title = title;
        entity.IsComplete = isComplete;
        await repository.UpdateAsync(entity, cancellationToken);
        return ToDto(entity);
    }

    public async Task<bool> DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var entity = await repository.GetByIdAsync(id, cancellationToken);
        if (entity is null) return false;

        await repository.DeleteAsync(entity, cancellationToken);
        return true;
    }

    private static TodoItemDto ToDto(TodoItem entity)
        => new(entity.Id, entity.Title, entity.IsComplete, entity.CreatedAt);
}
