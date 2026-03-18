namespace Starter.Shared.Exceptions;

public sealed class ForbiddenException(string message = "You do not have permission to perform this action.")
    : AppException(message);
