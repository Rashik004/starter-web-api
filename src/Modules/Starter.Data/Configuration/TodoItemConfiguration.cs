using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Starter.Data.Entities;

namespace Starter.Data.Configuration;

internal sealed class TodoItemConfiguration : IEntityTypeConfiguration<TodoItem>
{
    public void Configure(EntityTypeBuilder<TodoItem> builder)
    {
        builder.HasKey(t => t.Id);

        builder.Property(t => t.Title)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(t => t.CreatedAt)
            .IsRequired();

        // V2 columns
        builder.Property(t => t.Priority)
            .HasDefaultValue(TodoPriority.Medium);

        builder.Property(t => t.Tags)
            .HasMaxLength(500);

        builder.HasData(
            new TodoItem { Id = 1, Title = "Learn EF Core", IsComplete = true, CreatedAt = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc), Priority = TodoPriority.Medium },
            new TodoItem { Id = 2, Title = "Build an API", IsComplete = false, CreatedAt = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc), Priority = TodoPriority.Medium },
            new TodoItem { Id = 3, Title = "Deploy to production", IsComplete = false, CreatedAt = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc), Priority = TodoPriority.Medium }
        );
    }
}
