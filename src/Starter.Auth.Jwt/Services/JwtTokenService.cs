using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Starter.Auth.Shared.Entities;
using Starter.Auth.Shared.Options;

namespace Starter.Auth.Jwt.Services;

/// <summary>
/// Generates JWT access tokens for authenticated users.
/// Used by AuthController for login, register, and Google OAuth callback.
/// </summary>
public sealed class JwtTokenService(IOptions<JwtOptions> jwtOptions)
{
    public (string Token, int ExpiresIn) GenerateToken(AppUser user)
    {
        var options = jwtOptions.Value;
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(options.SecretKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var expiresMinutes = options.ExpirationMinutes;

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.Id),
            new Claim(JwtRegisteredClaimNames.Email, user.Email ?? string.Empty),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var token = new JwtSecurityToken(
            issuer: options.Issuer,
            audience: options.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(expiresMinutes),
            signingCredentials: credentials);

        return (new JwtSecurityTokenHandler().WriteToken(token), expiresMinutes * 60);
    }
}
