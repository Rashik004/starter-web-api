namespace Starter.Shared.Exceptions;

public sealed class NotFoundException(string message)
    : AppException(message);
