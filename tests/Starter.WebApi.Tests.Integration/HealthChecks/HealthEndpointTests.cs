using System.Text.Json;
using FluentAssertions;

namespace Starter.WebApi.Tests.Integration.HealthChecks;

public class HealthEndpointTests(CustomWebApplicationFactory factory)
    : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client = factory.CreateClient();

    [Theory]
    [InlineData("/health")]
    [InlineData("/health/ready")]
    [InlineData("/health/live")]
    public async Task HealthEndpoint_ReturnsOkStatus(string url)
    {
        var response = await _client.GetAsync(url);

        response.StatusCode.Should().Be(System.Net.HttpStatusCode.OK);
    }

    [Fact]
    public async Task HealthEndpoint_ReturnsJsonWithStatusField()
    {
        var response = await _client.GetAsync("/health");
        response.EnsureSuccessStatusCode();

        var content = await response.Content.ReadAsStringAsync();
        var json = JsonDocument.Parse(content).RootElement;

        json.GetProperty("status").GetString().Should().NotBeNullOrEmpty();
        json.TryGetProperty("results", out _).Should().BeTrue();
    }

    [Fact]
    public async Task ReadyEndpoint_ReturnsHealthyOrDegradedStatus()
    {
        var response = await _client.GetAsync("/health/ready");
        response.EnsureSuccessStatusCode();

        var content = await response.Content.ReadAsStringAsync();
        var json = JsonDocument.Parse(content).RootElement;

        // Ready endpoint includes external-service check which returns Degraded
        // when HealthChecks:ExternalServiceUri is empty (test config). ASP.NET Core
        // HealthChecks returns 200 for both Healthy and Degraded by default.
        var status = json.GetProperty("status").GetString();
        status.Should().BeOneOf("Healthy", "Degraded");
    }

    [Fact]
    public async Task LiveEndpoint_ReturnsHealthyStatus()
    {
        var response = await _client.GetAsync("/health/live");
        response.EnsureSuccessStatusCode();

        var content = await response.Content.ReadAsStringAsync();
        var json = JsonDocument.Parse(content).RootElement;

        json.GetProperty("status").GetString().Should().Be("Healthy");
    }
}
