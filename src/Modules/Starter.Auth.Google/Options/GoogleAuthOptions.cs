namespace Starter.Auth.Google.Options;

/// <summary>
/// Configuration for Google OAuth. Both ClientId and ClientSecret must be
/// non-empty for the Google authentication handler to be registered.
/// When either is empty, AddAppGoogle() is a safe no-op and the app starts
/// without Google login support.
/// </summary>
public sealed class GoogleAuthOptions
{
    public const string SectionName = "Authentication:Google";

    public string ClientId { get; set; } = string.Empty;

    public string ClientSecret { get; set; } = string.Empty;

    /// <summary>
    /// Returns true when both ClientId and ClientSecret are non-empty,
    /// meaning Google OAuth credentials have been configured.
    /// </summary>
    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(ClientId) && !string.IsNullOrWhiteSpace(ClientSecret);
}
