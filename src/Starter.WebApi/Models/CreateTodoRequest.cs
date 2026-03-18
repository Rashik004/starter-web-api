using System.ComponentModel.DataAnnotations;

namespace Starter.WebApi.Models;

public sealed record CreateTodoRequest(
    [Required, StringLength(200, MinimumLength = 1)] string Title);
