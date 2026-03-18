namespace Starter.Shared.Contracts;

public interface ITodoService
{
    Task<TodoItemDto?> GetByIdAsync(int id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<TodoItemDto>> GetAllAsync(CancellationToken cancellationToken = default);
    Task<TodoItemDto> CreateAsync(string title, CancellationToken cancellationToken = default);
    Task<TodoItemDto?> UpdateAsync(int id, string title, bool isComplete, CancellationToken cancellationToken = default);
    Task<bool> DeleteAsync(int id, CancellationToken cancellationToken = default);
}

public sealed record TodoItemDto(int Id, string Title, bool IsComplete, DateTime CreatedAt);

public sealed record TodoItemV2Dto(int Id, string Title, bool IsComplete, DateTime CreatedAt, string Priority, DateTime? DueDate, string? Tags);
