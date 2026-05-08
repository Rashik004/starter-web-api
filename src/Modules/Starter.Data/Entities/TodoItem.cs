namespace Starter.Data.Entities;

internal sealed class TodoItem
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public bool IsComplete { get; set; }
    public DateTime CreatedAt { get; set; }

    // V2 fields -- exposed only by TodoV2Controller, ignored by V1 DTO
    public TodoPriority Priority { get; set; } = TodoPriority.Medium;
    public DateTime? DueDate { get; set; }
    public string? Tags { get; set; }
}

internal enum TodoPriority
{
    Low = 0,
    Medium = 1,
    High = 2
}
