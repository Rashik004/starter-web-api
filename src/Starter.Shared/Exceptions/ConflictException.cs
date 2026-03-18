namespace Starter.Shared.Exceptions;

public sealed class ConflictException(string message)
    : AppException(message);
