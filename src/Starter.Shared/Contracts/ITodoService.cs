namespace Starter.Shared.Contracts;

public interface ITodoService
{
    Task<TodoItemDto?> GetByIdAsync(int id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<TodoItemDto>> GetAllAsync(CancellationToken cancellationToken = default);
    Task<TodoItemDto> CreateAsync(string title, CancellationToken cancellationToken = default);
    Task<TodoItemDto?> UpdateAsync(int id, string title, bool isComplete, CancellationToken cancellationToken = default);
    Task<bool> DeleteAsync(int id, CancellationToken cancellationToken = default);

    // V2 methods -- expanded DTO with priority, dueDate, tags
    Task<IReadOnlyList<TodoItemV2Dto>> GetAllV2Async(CancellationToken cancellationToken = default);
    Task<TodoItemV2Dto?> GetByIdV2Async(int id, CancellationToken cancellationToken = default);
    Task<TodoItemV2Dto> CreateV2Async(string title, string priority, DateTime? dueDate, string? tags, CancellationToken cancellationToken = default);
    Task<TodoItemV2Dto?> UpdateV2Async(int id, string title, bool isComplete, string priority, DateTime? dueDate, string? tags, CancellationToken cancellationToken = default);
}

public sealed record TodoItemDto(int Id, string Title, bool IsComplete, DateTime CreatedAt);

public sealed record TodoItemV2Dto(int Id, string Title, bool IsComplete, DateTime CreatedAt, string Priority, DateTime? DueDate, string? Tags);
