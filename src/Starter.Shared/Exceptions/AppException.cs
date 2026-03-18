namespace Starter.Shared.Exceptions;

/// <summary>
/// Base exception for all application-specific exceptions.
/// Provides a consistent base for typed exception mapping in the global handler.
/// </summary>
public abstract class AppException(string message, Exception? innerException = null)
    : Exception(message, innerException);
