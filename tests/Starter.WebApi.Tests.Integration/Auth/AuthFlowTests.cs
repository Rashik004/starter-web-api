using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;

namespace Starter.WebApi.Tests.Integration.Auth;

public class AuthFlowTests(AuthWebApplicationFactory factory)
    : IClassFixture<AuthWebApplicationFactory>
{
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task Register_WithValidCredentials_ReturnsCreatedWithToken()
    {
        var response = await _client.PostAsJsonAsync("/api/auth/register", new
        {
            Email = "newuser@test.com",
            Password = "Test1234!",
            ConfirmPassword = "Test1234!"
        });

        response.StatusCode.Should().Be(HttpStatusCode.Created);

        var content = await response.Content.ReadAsStringAsync();
        var json = JsonDocument.Parse(content).RootElement;

        json.GetProperty("accessToken").GetString().Should().NotBeNullOrEmpty();
        json.GetProperty("userId").GetString().Should().NotBeNullOrEmpty();
        json.GetProperty("email").GetString().Should().Be("newuser@test.com");
    }

    [Fact]
    public async Task Register_DuplicateEmail_ReturnsConflict()
    {
        // Register first user
        var firstResponse = await _client.PostAsJsonAsync("/api/auth/register", new
        {
            Email = "duplicate@test.com",
            Password = "Test1234!",
            ConfirmPassword = "Test1234!"
        });
        firstResponse.StatusCode.Should().Be(HttpStatusCode.Created);

        // Attempt duplicate registration
        var response = await _client.PostAsJsonAsync("/api/auth/register", new
        {
            Email = "duplicate@test.com",
            Password = "Test1234!",
            ConfirmPassword = "Test1234!"
        });

        response.StatusCode.Should().Be(HttpStatusCode.Conflict);
    }

    [Fact]
    public async Task Login_WithValidCredentials_ReturnsOkWithToken()
    {
        // Register user first
        var registerResponse = await _client.PostAsJsonAsync("/api/auth/register", new
        {
            Email = "logintest@test.com",
            Password = "Test1234!",
            ConfirmPassword = "Test1234!"
        });
        registerResponse.StatusCode.Should().Be(HttpStatusCode.Created);

        // Login
        var response = await _client.PostAsJsonAsync("/api/auth/login", new
        {
            Email = "logintest@test.com",
            Password = "Test1234!"
        });

        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var content = await response.Content.ReadAsStringAsync();
        var json = JsonDocument.Parse(content).RootElement;

        json.GetProperty("accessToken").GetString().Should().NotBeNullOrEmpty();
    }

    [Fact]
    public async Task Login_WithInvalidPassword_ReturnsUnauthorized()
    {
        // Register user first
        var registerResponse = await _client.PostAsJsonAsync("/api/auth/register", new
        {
            Email = "wrongpw@test.com",
            Password = "Test1234!",
            ConfirmPassword = "Test1234!"
        });
        registerResponse.StatusCode.Should().Be(HttpStatusCode.Created);

        // Login with wrong password
        var response = await _client.PostAsJsonAsync("/api/auth/login", new
        {
            Email = "wrongpw@test.com",
            Password = "WrongPassword1!"
        });

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Register_Login_AccessProtected_FullRoundTrip()
    {
        // Step 1: Register
        var registerResponse = await _client.PostAsJsonAsync("/api/auth/register", new
        {
            Email = "roundtrip@test.com",
            Password = "Test1234!",
            ConfirmPassword = "Test1234!"
        });
        registerResponse.StatusCode.Should().Be(HttpStatusCode.Created);

        var registerContent = await registerResponse.Content.ReadAsStringAsync();
        var registerJson = JsonDocument.Parse(registerContent).RootElement;
        var token = registerJson.GetProperty("accessToken").GetString();
        token.Should().NotBeNullOrEmpty();

        // Step 2: Set Authorization header with the JWT
        _client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", token);

        // Step 3: Access protected endpoint
        var response = await _client.GetAsync("/api/v1/todos");

        response.StatusCode.Should().Be(HttpStatusCode.OK,
            "the JWT token from registration should grant access to protected endpoints");
    }

    [Fact]
    public async Task AccessProtected_WithoutToken_ReturnsUnauthorized()
    {
        // Create a new client without any auth headers
        var unauthenticatedClient = factory.CreateClient();

        var response = await unauthenticatedClient.GetAsync("/api/v1/todos");

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }
}
