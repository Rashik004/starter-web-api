namespace Starter.WebApi.Models;

public sealed record CreateTodoV2Request(
    string Title,
    string Priority,
    DateTime? DueDate,
    string? Tags);
