namespace Starter.Shared.Exceptions;

public sealed class UnauthorizedException(string message = "Authentication is required.")
    : AppException(message);
