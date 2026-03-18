namespace Starter.WebApi.Models;

public sealed record RegisterRequest(string Email, string Password, string ConfirmPassword);
