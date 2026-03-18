using System.ComponentModel.DataAnnotations;

namespace Starter.Auth.Shared.Options;

public sealed class JwtOptions
{
    public const string SectionName = "Jwt";

    [Required]
    public string SecretKey { get; set; } = string.Empty;

    [Required]
    public string Issuer { get; set; } = string.Empty;

    [Required]
    public string Audience { get; set; } = string.Empty;

    [Range(1, 1440)]
    public int ExpirationMinutes { get; set; } = 60;
}
