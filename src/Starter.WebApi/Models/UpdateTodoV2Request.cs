namespace Starter.WebApi.Models;

public sealed record UpdateTodoV2Request(
    string Title,
    bool IsComplete,
    string Priority,
    DateTime? DueDate,
    string? Tags);
