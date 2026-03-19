using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Starter.WebApi.Tests.Integration.Helpers;

internal sealed class FakeAuthHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, TestConstants.TestUserId),
            new Claim(ClaimTypes.Email, TestConstants.TestEmail),
            new Claim(ClaimTypes.Name, TestConstants.TestUserName),
        };

        var identity = new ClaimsIdentity(claims, TestConstants.TestScheme);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, TestConstants.TestScheme);

        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
