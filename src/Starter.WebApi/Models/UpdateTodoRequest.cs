using System.ComponentModel.DataAnnotations;

namespace Starter.WebApi.Models;

public sealed record UpdateTodoRequest(
    [Required, StringLength(200, MinimumLength = 1)] string Title,
    bool IsComplete);
