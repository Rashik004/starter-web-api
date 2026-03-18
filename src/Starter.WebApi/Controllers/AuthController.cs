using Asp.Versioning;
using FluentValidation;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Starter.Auth.Jwt.Services;
using Starter.Auth.Shared.Constants;
using Starter.Auth.Shared.Entities;
using Starter.Shared.Exceptions;
using Starter.WebApi.Models;

namespace Starter.WebApi.Controllers;

/// <summary>
/// Authentication endpoints for user registration, login, and Google OAuth.
/// Returns JWT access tokens for API authentication.
/// </summary>
[ApiController]
[Route("api/auth")]
[ApiVersionNeutral]
public class AuthController(
    UserManager<AppUser> userManager,
    SignInManager<AppUser> signInManager,
    JwtTokenService tokenService) : ControllerBase
{
    /// <summary>
    /// Registers a new user and returns a JWT access token (auto-login on registration).
    /// </summary>
    /// <response code="201">User created with access token</response>
    /// <response code="422">Validation errors</response>
    /// <response code="409">Email already registered</response>
    [HttpPost("register")]
    [AllowAnonymous]
    public async Task<IActionResult> Register(
        RegisterRequest request,
        [FromServices] IValidator<RegisterRequest> validator,
        CancellationToken ct)
    {
        var validationResult = await validator.ValidateAsync(request, ct);
        if (!validationResult.IsValid)
        {
            var errors = validationResult.Errors
                .GroupBy(e => e.PropertyName)
                .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray());
            throw new AppValidationException(errors);
        }

        var user = new AppUser { UserName = request.Email, Email = request.Email };
        var result = await userManager.CreateAsync(user, request.Password);

        if (!result.Succeeded)
        {
            if (result.Errors.Any(e => e.Code == "DuplicateEmail" || e.Code == "DuplicateUserName"))
            {
                throw new ConflictException($"A user with email '{request.Email}' already exists");
            }

            var identityErrors = result.Errors
                .GroupBy(e => "Identity")
                .ToDictionary(g => g.Key, g => g.Select(e => e.Description).ToArray());
            throw new AppValidationException(identityErrors);
        }

        var (token, expiresIn) = tokenService.GenerateToken(user);
        return StatusCode(StatusCodes.Status201Created, new
        {
            userId = user.Id,
            email = user.Email,
            accessToken = token,
            expiresIn
        });
    }

    /// <summary>
    /// Authenticates a user and returns a JWT access token.
    /// </summary>
    /// <response code="200">Login successful with access token</response>
    /// <response code="401">Invalid credentials</response>
    /// <response code="422">Validation errors</response>
    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login(
        LoginRequest request,
        [FromServices] IValidator<LoginRequest> validator,
        CancellationToken ct)
    {
        var validationResult = await validator.ValidateAsync(request, ct);
        if (!validationResult.IsValid)
        {
            var errors = validationResult.Errors
                .GroupBy(e => e.PropertyName)
                .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray());
            throw new AppValidationException(errors);
        }

        var user = await userManager.FindByEmailAsync(request.Email);
        if (user is null)
            throw new UnauthorizedException("Invalid credentials");

        var result = await signInManager.CheckPasswordSignInAsync(
            user, request.Password, lockoutOnFailure: true);
        if (!result.Succeeded)
            throw new UnauthorizedException("Invalid credentials");

        var (token, expiresIn) = tokenService.GenerateToken(user);
        return Ok(new { accessToken = token, expiresIn });
    }

    /// <summary>
    /// Initiates Google OAuth login. Redirects to Google, then returns a JWT on callback.
    /// </summary>
    [HttpGet("google")]
    [AllowAnonymous]
    public IActionResult GoogleLogin()
    {
        var properties = new AuthenticationProperties
        {
            RedirectUri = Url.Action(nameof(GoogleCallback))
        };
        return Challenge(properties, AuthConstants.GoogleScheme);
    }

    /// <summary>
    /// Handles the Google OAuth callback. Creates or finds user, returns JWT.
    /// </summary>
    [HttpGet("google-callback")]
    [AllowAnonymous]
    public async Task<IActionResult> GoogleCallback()
    {
        var authenticateResult = await HttpContext.AuthenticateAsync(AuthConstants.GoogleScheme);
        if (!authenticateResult.Succeeded || authenticateResult.Principal is null)
            throw new UnauthorizedException("Google authentication failed");

        var email = authenticateResult.Principal.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value;
        if (string.IsNullOrEmpty(email))
            throw new UnauthorizedException("Google account does not have an email");

        var user = await userManager.FindByEmailAsync(email);
        if (user is null)
        {
            user = new AppUser { UserName = email, Email = email, EmailConfirmed = true };
            var createResult = await userManager.CreateAsync(user);
            if (!createResult.Succeeded)
            {
                var errors = createResult.Errors
                    .GroupBy(e => "Identity")
                    .ToDictionary(g => g.Key, g => g.Select(e => e.Description).ToArray());
                throw new AppValidationException(errors);
            }
        }

        var (token, expiresIn) = tokenService.GenerateToken(user);
        return Ok(new { accessToken = token, expiresIn });
    }
}
